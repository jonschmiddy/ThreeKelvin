extends Node

## Jon, Nov 3: every station has all five decks at every level; the lab and board used to hide.
## The lab's glass, its zoom (`LabZoom`) and its pages pass the box test at every level.
## Why: docs/why/StationDeckTest.md#test-purpose

var harness := Harness.new()
var _tree: SceneTree

## RELIC ANALYSIS's bill at each level: 40 credits by `Market.service_index`.
const PRICES := [45, 40, 35, 32, 30]
## AUGMENT's credits at each level (5 DATA beside them), and STRIP's (2 DATA).
const AUGMENT := [22, 20, 18, 16, 15]
const STRIP := [11, 10, 9, 8, 7]
## The chart's destination panel width (`NameFit.PANEL_W`).
const PANEL_W := 228.0


func _ok(what: String, c: bool) -> bool:
	return harness._ok(what, c)


func _ready() -> void:
	_tree = get_tree()
	_run.call_deferred()


func _run() -> void:
	await _tree.process_frame
	_dock_desk_rule()
	_operators_fit()
	_one_repair_drone()
	for dev in 5:
		for berth: bool in [false, true]:
			await _decks(dev, berth)
	for dev in 5:
		await _every_ride(dev)
	for dev: int in [MapGen.Development.OUTPOST, MapGen.Development.SETTLEMENT, MapGen.Development.CITY]:
		await _bare(dev)
	await _second_station()
	await _chart()
	harness.verdict("stationdecktest")
	_tree.quit(harness.code())


## The dock desk from the map alone: none with a berth, stable, one per berthless station.
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
	# Pinned to text order: `keys().sort()` on StringNames sorts by address, unseen in one process.
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
	# One process keeps one address order, so reversed fresh StringNames expose the fault.
	# Addresses differed per process on Nov 3; checked failing on a `keys().sort()` pick.
	# Why: docs/why/StationDeckTest.md#address-order
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
## PATCH and REPAIR are one job with 8 or less missing: PATCH stays away then
## (Jon, Nov 9, stripped-down UI 7), and both come with more missing.
func _one_repair_drone() -> void:
	var here := _station(MapGen.Development.CITY, true, 9190)
	for row: Array in [[5, "USE REPAIR", ""], [8, "USE REPAIR", ""], [9, "", ""], [20, "", ""], [0, "HULL FULL", "HULL FULL"]]:
		Run.hp = Run.max_hp() - int(row[0])
		var o := YardDrones.repair_offers(here)
		_ok("%d missing: PATCH \"%s\" (%s), REPAIR \"%s\" (%s)" % [row[0], o[0].done, o[0].label, o[1].done, o[1].label],
			String(o[0].done) == String(row[1]) and String(o[1].done) == String(row[2]))
	Run.hp = Run.max_hp()


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
	await Harness.frames(_tree, 30)
	return Router.current as StationScreen


## Open a deck by its button and wait (wall clock: the lamp and the scan run on
## it) for its main thing to be up.
func _open(st: StationScreen, id: StringName) -> bool:
	(st._tabs[id] as Button).pressed.emit()
	# (a few frames first: the deck's power-on shuts the lab's holder and then
	# scans it open, so it is whole for a moment before it starts)
	await Harness.frames(_tree, 3)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000 and not st.deck_subject(id).has_area():
		await _tree.process_frame
	await Harness.frames(_tree, 4)
	if not st.deck_subject(id).has_area():
		print("    %s not up after %d ms: tab %s, page shown %s, clip %s of glass %s, the screen %s" % [id,
			Time.get_ticks_msec() - t0, st._tab, (st._pages[id] as Control).is_visible_in_tree(),
			st._bench_clip.size, st._lab.glass_rect().size, st._login.state])
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
	_ok("%s: an offer's SIGN is on the board" % tag, Harness.button_with_text(st._work, "SIGN") != null)
	_ok("%s: no NO WORK POSTED. note on a board with work" % tag, _find_label(st._work, StationScreen.NO_WORK) == null)

	# A JOB SIGNED HERE IS HANDED IN HERE: done, it is deliverable at this desk,
	# the chart's search finds this desk, and the board puts up its DELIVER.
	if offers.is_empty():
		return
	var job := Run.take_contract(offers[0])
	if job.kind == ContractData.Kind.HEAT:
		# (a heat job is handed in with the heat on the hull, still TAKEN)
		Run.heat = job.amount + 1
	else:
		job.state = ContractData.State.READY
	Sig.resources_changed.emit()
	await Harness.frames(_tree, 6)
	var at_desk := Run.deliverable_at(here).has(job) or Run.heat_deliverable_at(here).has(job)
	_ok("%s: a %s job signed here can be handed in here" % [tag, String(ContractData.Kind.keys()[job.kind]).to_lower()], at_desk)
	_ok("%s: and the chart counts this desk as its berth" % tag, ContractData.berth_of(here, job.manufacturer))
	var hand_in := Harness.button_with_text(st._work, "DELIVER") if job.kind != ContractData.Kind.HEAT \
		else Harness.button_with_text(st._work, "OFFLOAD %d HEAT" % job.amount)
	_ok("%s: the board shows it a button to hand it in" % tag, hand_in != null)
	if hand_in != null:
		var cash := Run.credits
		hand_in.pressed.emit()
		await Harness.frames(_tree, 6)
		_ok("%s: and pressed, it pays (%d -> %d)" % [tag, cash, Run.credits], Run.credits > cash)


## A board with nothing to post keeps its tab and says NO WORK POSTED. on a note.
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
	await Harness.frames(_tree, 4)
	var kids := st._work.get_child_count()
	var note := _find_label(st._work, StationScreen.NO_WORK)
	_ok("%s: one note says %s (%d on the board)" % [tag, StationScreen.NO_WORK, kids], note != null and kids == 1)
	if note != null:
		var board := st._board.get_global_rect()
		_ok("%s: and it is on the board %s (%s)" % [tag, board, note.get_global_rect()],
			note.is_visible_in_tree() and board.encloses(note.get_global_rect()))


## THE CHART at a dock desk station: the star's tag reads <MANUFACTURER> DESK.
func _chart() -> void:
	var here := _station(MapGen.Development.OUTPOST, false, 9100)
	var desk := Contracts.dock_desk(here)
	var st := await _dock(here)
	if st == null:
		_ok("chart: the station is up", false)
		return
	Router.show_starchart()
	await Harness.frames(_tree, 20)
	var ch := Router.current as StarchartScreen
	if not _ok("chart: the star chart is up", ch != null):
		return
	ch._on_node_picked(here.index)
	await Harness.frames(_tree, 6)
	# THE STAR'S TAG IS A FEW LINES (Jon, Nov 9, Q1): the name, what is there, the place and
	# danger with fuel; the survey is gone, and the panel keeps danger, fuel and warnings.
	var tip := ch._chart.tip_lines(here, here)
	_ok("chart: the star's tag is %d lines, the name first and danger last: %s" % [tip.size(), " / ".join(tip)],
		tip.size() == 4 and tip[0] == MapGen.star_name(here) and tip[3].begins_with("DANGER"))
	var ls: Array = []
	for l in tip:
		ls.append([l, UITheme.COLD])
	var tag_w := TornTag.measure(ls).x
	_ok("chart: the tag fits inside the chart (%.0f of %.0f)" % [tag_w, ch._chart.size.x], tag_w < ch._chart.size.x)
	var rows_bottom := ch._rows.get_global_rect().end.y
	# (docked, UNDOCK FIRST stands where JUMP would: stripped-down UI 5, Nov 9)
	var slot: Control = ch._undock_first if Router.docked else ch._jump
	var jump := slot.get_global_rect()
	var screen_h: float = ch.get_viewport_rect().size.y
	print("    chart rows end at %.0f, JUMP %.0f to %.0f of %.0f" % [rows_bottom, jump.position.y, jump.end.y, screen_h])
	_ok("chart: the blurb is off with a star picked, the rows down to danger, fuel and warnings (%d)" % ch._rows.get_child_count(),
		not ch._dest_blurb.visible and ch._rows.get_child_count() <= 2 + MapGen.hazards(here).size())
	_ok("chart: JUMP (docked, UNDOCK FIRST in its place) is on screen and below the rows",
		slot.is_visible_in_tree() and jump.end.y <= screen_h + 0.5 and jump.position.y >= rows_bottom - 0.5)


## THE LABORATORY'S SCREEN AND THE CAMERA INTO IT (science S9, Jon's 1C, Nov 4:
## "is the screen really big enough for a player to see all of it?"). The room's
## entry fits the glass at every level; the zoomed RECIPES and RESEARCH pass
## the box test; and, where `deep`, the board in its used states, BUY's rules
## and the board at a second station.
func _lab(st: StationScreen, here: MapGen.MapNode, tag: String, dev: int, deep: bool) -> void:
	var zoom := st.lab_zoom()
	var login := st._login
	await _sign_on(st, tag, dev, deep)
	await _glass_only(st, tag)

	# INTO THE GLASS, by the glass, then RECIPES (the pointer then off the glass,
	# onto the board, as the overlay takes it)
	st._glass_press.notification(Control.NOTIFICATION_MOUSE_EXIT)
	await _click(st._glass_press)
	st._glass_press.notification(Control.NOTIFICATION_MOUSE_EXIT)
	await Harness.frames(_tree, 3)
	if not _ok("%s: the glass moves the camera onto it and lands on RESEARCH (open %s, landed %s, tab %s, the screen %s)"
			% [tag, zoom.is_open(), zoom.landed(), zoom.tab, login.state],
			zoom.is_open() and zoom.landed() and zoom.tab == &"research" and login.state == LabLogin.SIGNING):
		return
	_landed(st, zoom, tag, dev)
	await _recipes_page(zoom, here, tag, dev)

	# RESEARCH: the board, with no step, some and all of them bought
	await _click(zoom.tab_buttons[&"research"])
	await Harness.frames(_tree, 2)
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
				await Harness.frames(_tree, 2)
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

	# BACK OUT: LEAVE, and Esc, each to the logo
	await _click(zoom.leave_button)
	await Harness.frames(_tree, 2)
	_ok("%s: LEAVE takes the camera back out to the logo (open %s, shown %s, the screen %s)" % [tag, zoom.is_open(), zoom.visible, login.state],
		not zoom.is_open() and not zoom.visible and login.state == LabLogin.LOGO and st._screen_pic.is_visible_in_tree())
	st._glass_press.pressed.emit()
	await Harness.frames(_tree, 2)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	st.get_viewport().push_input(esc)
	await Harness.frames(_tree, 2)
	_ok("%s: the glass goes in, and Esc comes back out to the logo (open %s, the screen %s)" % [tag, zoom.is_open(), login.state],
		not zoom.is_open() and not zoom.visible and login.state == LabLogin.LOGO)
	# (and at the capital with a berth: the yard's edge sets the rail's alpha
	# every frame there, and undid the chrome's going)
	var big := dev == MapGen.Development.CAPITAL or dev == MapGen.Development.SETTLEMENT
	if (deep and big) or (not deep and dev == MapGen.Development.CAPITAL):
		await _camera_move(st, zoom, tag)
		await _deck_ride(st, tag)


## RECIPES IN AUGMENT'S LAYOUT (Jon, Nov 5: "Can't we make the recipes page like the augment
## page in its layout?"; `LabRecipes`).
## Why: docs/why/StationDeckTest.md#recipes-in-augments-layout
func _recipes_page(zoom: LabZoom, here: MapGen.MapNode, tag: String, dev: int) -> void:
	var rec := zoom.recipes
	var data_was := Run.data
	var cr_was := Run.credits
	Run.credits = maxi(Run.credits, 300)
	for id: StringName in [&"survey_film", &"relic"]:
		Run.spend_material(id, Run.material(id))
	Sig.resources_changed.emit()
	await _click(zoom.tab_buttons[&"recipes"])
	await Harness.frames(_tree, 2)
	if not _ok("%s: RECIPES is on show" % tag, zoom.tab == &"recipes" and rec.is_visible_in_tree()):
		return
	var words := func() -> Array:
		return rec.leaves.map(func(l: Array) -> String: return str(l[0]))
	# NOTHING HELD
	var ids: Array = rec._rings.map(func(g: Dictionary) -> StringName: return StringName(g.r.id))
	var sts: Array = rec._rings.map(func(g: Dictionary) -> StringName: return g.st)
	var w0: Array = words.call()
	var bad0 := zoom.check()
	_ok("%s: RECIPES with nothing held greys all three recipes with what each needs, and has no key (%s %s; %s)" % [tag, ids, sts,
		"clean" if bad0.is_empty() else "; ".join(bad0)],
		rec.empty() and rec.hand == &"" and ids == [&"develop", &"read", &"analysis"]
		and sts.all(func(x: StringName) -> bool: return x == &"later") and not rec.commit_button.visible
		and w0.has("NOTHING TO MAKE") and w0.has("NEEDS A ROLL OF FILM") and w0.has("NEEDS A RELIC")
		and w0.has("NEEDS A RELIC + %d CREDITS" % PRICES[dev]) and w0.has("NONE  ·  FROM WRECKS, DANGER 7+")
		and bad0.is_empty())
	var prices: Array = rec._rings.map(func(g: Dictionary) -> int: return Fabricator.price(here, g.r))
	# A CLICK ON A FADED ROW with nothing aboard: the page stays empty, no key,
	# and the row does not look pressable
	var row0 := rec.get_global_transform() * Vector2(LabRecipes.RAIL_X + 120, int(rec._items[0].cy))
	await _click_at(row0)
	await Harness.frames(_tree, 2)
	_ok("%s: with nothing aboard a click on a faded row leaves the page empty, with no key and no hand cursor (%s)" % [tag, rec.hand],
		rec.hand == &"" and not rec.commit_button.visible and rec.row_at(Vector2(LabRecipes.RAIL_X + 120, int(rec._items[0].cy))) == -1
		and rec.leaves.any(func(l: Array) -> bool: return str(l[0]) == "NOTHING TO MAKE"))
	_ok("%s: RELIC ANALYSIS costs %d credits, DEVELOP FILM and READ FOR DATA none (%s)" % [tag, PRICES[dev], prices],
		prices == [0, 0, PRICES[dev]])
	# TWO ROLLS AND A RELIC
	for i in 2:
		Run.place_in_hold(MaterialData.of(MaterialTable.by_id(&"survey_film")))
	Run.place_in_hold(MaterialData.of(MaterialTable.by_id(&"relic")))
	Sig.resources_changed.emit()
	await Harness.frames(_tree, 2)
	var film_line := "2 ROLLS  ·  SELLS FOR %d" % Market.material_price(here, &"survey_film")
	var w1: Array = words.call()
	var bad1 := zoom.check()
	_ok("%s: with two rolls and a relic the film is on the bench, DEVELOP FILM picked with MAKE for %s (%s; %s)" % [tag, rec.bill_words,
		film_line, "clean" if bad1.is_empty() else "; ".join(bad1)],
		rec.hand == &"survey_film" and rec._rings.size() == 1 and rec.picked().get("id") == &"develop"
		and rec._rings[0].st == &"next" and rec.commit_button.visible and not rec.commit_button.disabled
		and rec.bill_words == "1 ROLL" and w1.has(film_line) and bad1.is_empty())
	# A CLICK ON THE RELIC'S ROW, then on each of its rings
	await _click_at(rec.get_global_transform() * Vector2(LabRecipes.RAIL_X + 120, int(rec._items[1].cy)))
	await Harness.frames(_tree, 2)
	var rids: Array = rec._rings.map(func(g: Dictionary) -> StringName: return StringName(g.r.id))
	_ok("%s: a click on the relic's row puts it on the bench, READ FOR DATA and RELIC ANALYSIS off it (%s)" % [tag, rids],
		rec.hand == &"relic" and rids == [&"read", &"analysis"])
	var bills := ["1 RELIC", "1 RELIC + %d CREDITS" % PRICES[dev]]
	for i2 in 2:
		await _click_at(rec.get_global_transform() * Vector2(rec._rings[i2].at))
		await Harness.frames(_tree, 2)
		var bad2 := zoom.check()
		_ok("%s: a click on ring %d picks %s, its bill %s (%s)" % [tag, i2, rids[i2], rec.bill_words, "clean" if bad2.is_empty() else "; ".join(bad2)],
			rec.choice == i2 and rec._rings[i2].st == &"next" and rec.bill_words == bills[i2] and bad2.is_empty())
	# MAKE THROUGH THIRTY REFRESHES, then clicked: a roll developed
	await _click_at(rec.get_global_transform() * Vector2(LabRecipes.RAIL_X + 120, int(rec._items[0].cy)))
	await Harness.frames(_tree, 2)
	var key := rec.commit_button
	for i3 in 30:
		Sig.resources_changed.emit()
		if i3 % 10 == 0:
			await Harness.frames(_tree, 1)
	await Harness.frames(_tree, 2)
	_ok("%s: MAKE is the same object after 30 refreshes, the film still in hand" % tag,
		is_instance_valid(key) and rec.commit_button == key and key.visible and not key.disabled and rec.hand == &"survey_film")
	var d0 := Run.data
	await _click(key)
	await Harness.frames(_tree, 2)
	var w3: Array = words.call()
	var one_line := "1 ROLL  ·  SELLS FOR %d" % Market.material_price(here, &"survey_film")
	var bad3 := zoom.check()
	_ok("%s: MAKE clicked develops a roll: film 2 to %d, DATA %d to %d, the rail says %s, the header %s, the strip says it (%s)" % [tag,
		Run.material(&"survey_film"), d0, Run.data, one_line, zoom._note, "clean" if bad3.is_empty() else "; ".join(bad3)],
		Run.material(&"survey_film") == 1 and Run.data == d0 + 6 and w3.has(one_line) and zoom._note == "+6"
		and rec.done.get("id") == &"develop" and w3.has("THE LAB GOT 6 DATA OUT OF IT.") and key.visible and not key.disabled
		and bad3.is_empty())
	# RELIC ANALYSIS clicked: the relic read out as a part
	await _click_at(rec.get_global_transform() * Vector2(LabRecipes.RAIL_X + 120, int(rec._items[1].cy)))
	await Harness.frames(_tree, 2)
	await _click_at(rec.get_global_transform() * Vector2(rec._rings[1].at))
	await Harness.frames(_tree, 2)
	var c0 := Run.credits
	await _click(key)
	await Harness.frames(_tree, 2)
	var w4: Array = words.call()
	var bad4 := zoom.check()
	var made := str(rec.done.get("line", ""))
	_ok("%s: MAKE clicked on RELIC ANALYSIS reads the relic out (relics %d, credits %d to %d, %s), the rail says none, the key is gone (%s)" % [tag,
		Run.material(&"relic"), c0, Run.credits, made, "clean" if bad4.is_empty() else "; ".join(bad4)],
		Run.material(&"relic") == 0 and Run.credits == c0 - PRICES[dev] and made.begins_with("The fragment reads out as")
		and w4.has(made.to_upper()) and w4.has("NONE  ·  FROM WRECKS, DANGER 7+") and not key.visible
		and rec._rings.all(func(g: Dictionary) -> bool: return g.st == &"later") and bad4.is_empty())
	Run.spend_material(&"survey_film", Run.material(&"survey_film"))
	Run.data = data_was
	Run.credits = cr_was
	Sig.resources_changed.emit()
	await Harness.frames(_tree, 1)


## THE LAB'S SCREEN AT REST (Jon, Nov 5; the savers, Nov 7): each of the owner's savers, at rest
## and signing in under the pointer, fits its window, the window its glass.
## Why: docs/why/StationDeckTest.md#the-labs-screen-at-rest
func _sign_on(st: StationScreen, tag: String, dev: int, deep: bool) -> void:
	var login := st._login
	var lab := st._lab
	var win := lab.win_rect()
	var xf := lab.get_global_transform()
	var glass_g := Rect2(xf * lab.glass_rect().position, lab.glass_rect().size * xf.get_scale().x)
	_ok("%s: the sign-on is the screen's window %s, inside the glass %s, and the glass's holder is the glass (%s)" % [tag, win, lab.glass_rect(), st._bench_clip.get_global_rect()],
		lab.glass_rect().encloses(win) and login.size == win.size and Vector2(st._screen_vp.size) == win.size
		and st._bench_clip.get_global_rect().is_equal_approx(glass_g)
		and st._bench_clip.get_global_rect().encloses(st._screen_pic.get_global_rect())
		and login.get_child_count() == 0)
	# AT REST: the owner's savers, the one up drawn whole
	st._glass_press.notification(Control.NOTIFICATION_MOUSE_EXIT)
	await Harness.frames(_tree, 3)
	var owner := "INDEPENDENT" if deep else "KORVAN"
	var list := login.savers()
	var own: Array = LabSavers.OWN[LabSavers.owner_key(login.owner_id)]
	var all_in := list.size() == 10 and own.all(func(c: String) -> bool: return list.has(c)) and LabSavers.KEPT.all(func(c: String) -> bool: return list.has(c))
	var up := login.code()
	var bad := login.check()
	var words: Array = login.leaves.map(func(l: Array) -> String: return str(l[0]))
	_ok("%s: at rest the screen runs %s's savers (%s), %s up, drawn (%d boxes) and passing the box test in %s (%s)" % [tag, owner, ",".join(list), up,
		words.size(), win.size, "clean" if bad.is_empty() else "; ".join(bad)],
		login.state == LabLogin.LOGO and login.owner_short() == owner and all_in and list.has(up) and words.size() >= 2 and bad.is_empty())
	var cut := _cut_at_landing(st)
	_ok("%s: the saver is laid out in what the landed camera keeps (%s), every box inside 960x540 there (%s)" % [tag, login.safe,
		"all in" if cut.is_empty() else "; ".join(cut)], cut.is_empty() and login.safe.has_area())
	# POINTED AT: the saver's own sign-in
	st._glass_press.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await Harness.frames(_tree, 2)
	var was := login.state
	await _until(func() -> bool: return login._t >= 0.7, 4000)
	await Harness.frames(_tree, 2)
	bad = login.check()
	words = login.leaves.map(func(l: Array) -> String: return str(l[0]))
	var cue := words.any(func(w: String) -> bool: return w.contains("SIGN IN"))
	_ok("%s: pointed at, %s shows its sign-in (%s), and passes the box test (%s)" % [tag, login.code(),
		", ".join(words), "clean" if bad.is_empty() else "; ".join(bad)],
		was == LabLogin.LOGIN and login.state == LabLogin.LOGIN and login.code() == up and cue and bad.is_empty())
	cut = _cut_at_landing(st)
	_ok("%s: the sign-in's every box is inside 960x540 once the camera has landed (%s)" % [tag, "all in" if cut.is_empty() else "; ".join(cut)],
		cut.is_empty())
	# THE CUE: CLICK TO SIGN IN breathes, brightness only
	var inks: Array[float] = []
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(LabLogin.PULSE_S * 1000.0):
		inks.append(login.cue_ink())
		await _tree.process_frame
	_ok("%s: CLICK TO SIGN IN breathes between %.2f and %.2f" % [tag, inks.min(), inks.max()],
		inks.min() >= LabLogin.PULSE_LO - 0.001 and inks.max() >= 0.97 and inks.max() <= 1.0)
	# and away again: the same saver at rest
	st._glass_press.notification(Control.NOTIFICATION_MOUSE_EXIT)
	await Harness.frames(_tree, 3)
	bad = login.check()
	_ok("%s: pointed away, %s at rest again (%s), the same one (%s), the box test %s" % [tag, login.code(), login.state, up, "clean" if bad.is_empty() else "; ".join(bad)],
		login.state == LabLogin.LOGO and login.code() == up and bad.is_empty())


## THE GLASS IS THE ONLY KEY: the one button on the lab's deck, the glass
## exactly; a click just off it on any side opens nothing, one just inside any
## corner opens the Lab; Enter and the pad's A press it too.
func _glass_only(st: StationScreen, tag: String) -> void:
	var zoom := st.lab_zoom()
	var keys := _buttons(st._pages[&"bench"] as Node)
	var g := st._glass_press.get_global_rect()
	_ok("%s: the only key on the lab's deck is the glass (%d keys), the whole glass and nothing else (%s, the glass %s)" % [tag, keys.size(), g, st._bench_clip.get_global_rect()],
		keys.size() == 1 and keys[0] == st._glass_press and g.is_equal_approx(st._bench_clip.get_global_rect()))
	var opened_off: Array[String] = []
	for at: Vector2 in [Vector2(g.position.x - 3, g.get_center().y), Vector2(g.end.x + 3, g.get_center().y),
			Vector2(g.get_center().x, g.position.y - 3), Vector2(g.get_center().x, g.end.y + 3)]:
		st._glass_press.notification(Control.NOTIFICATION_MOUSE_EXIT)
		await _click_at(at)
		await Harness.frames(_tree, 2)
		if zoom.is_open():
			opened_off.append(str(at))
			zoom.close()
			await Harness.frames(_tree, 2)
	_ok("%s: a click 3 px off the glass on each side opens nothing (%s)" % [tag, "none did" if opened_off.is_empty() else ", ".join(opened_off)], opened_off.is_empty())
	var missed: Array[String] = []
	for at2: Vector2 in [g.position + Vector2(2, 2), Vector2(g.end.x - 3, g.position.y + 2), Vector2(g.position.x + 2, g.end.y - 3), g.end - Vector2(3, 3)]:
		st._glass_press.notification(Control.NOTIFICATION_MOUSE_ENTER)
		await _click_at(at2)
		await Harness.frames(_tree, 2)
		if not zoom.is_open():
			missed.append(str(at2))
		zoom.close()
		st._glass_press.notification(Control.NOTIFICATION_MOUSE_EXIT)
		await Harness.frames(_tree, 2)
	_ok("%s: a click 2 px inside each corner of the glass opens the Lab (%s)" % [tag, "every one did" if missed.is_empty() else "missed " + ", ".join(missed)], missed.is_empty())
	var target := GameShell.input_target(_tree)
	var by: Array[String] = []
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	for ev: InputEvent in [enter, pad]:
		target.push_input(ev)
		await Harness.frames(_tree, 2)
		if zoom.is_open():
			by.append("Enter" if ev == enter else "pad A")
		zoom.close()
		await Harness.frames(_tree, 2)
	_ok("%s: Enter and the pad's A press the glass (%s)" % [tag, ", ".join(by)], by.size() == 2)
	# and the pad's B takes the camera back out, as Esc does
	target.push_input(pad)
	await Harness.frames(_tree, 2)
	var in_by_a := zoom.is_open()
	var b_ev := InputEventJoypadButton.new()
	b_ev.button_index = JOY_BUTTON_B
	b_ev.pressed = true
	target.push_input(b_ev)
	await Harness.frames(_tree, 2)
	_ok("%s: the pad's B takes the camera back out (in by A %s, open after B %s)" % [tag, in_by_a, zoom.is_open()],
		in_by_a and not zoom.is_open())
	zoom.close()
	await Harness.frames(_tree, 2)


## Every button showing under `n`.
func _buttons(n: Node) -> Array[BaseButton]:
	var out: Array[BaseButton] = []
	if n is BaseButton and (n as BaseButton).is_visible_in_tree():
		out.append(n as BaseButton)
	for c in n.get_children():
		out.append_array(_buttons(c))
	return out


## The sign-on's boxes, in the look it has now, that the landed camera would put
## outside the 960x540 window (`LabZoom.landed_origin`, the lab's zoom).
func _cut_at_landing(st: StationScreen) -> Array[String]:
	var lab := st._lab
	var z := float(LabZoom.ZOOM.get(lab._level, 3))
	var o := LabZoom.landed_origin(lab)
	var wp := lab.win_rect().position
	var out: Array[String] = []
	for l: Array in st._login.leaves:
		var r: Rect2i = l[1]
		var sr := Rect2(o + (wp + Vector2(r.position)) * z, Vector2(r.size) * z)
		if not Rect2(0, 0, LabZoom.W, LabZoom.H).encloses(sr):
			out.append("'%s' at %s" % [l[0], sr])
	return out


## THE CAMERA LANDED: one uniform zoom, the lab's whole number, the room one
## picture at it, the glass centred and the board's glass inside it on screen;
## at one less the board would not fit. Where the glass covers the window the
## room is not drawn under the pages; where its bezel shows, it is.
func _landed(st: StationScreen, zoom: LabZoom, tag: String, _dev: int) -> void:
	var lab := st._lab
	var z := int(LabZoom.ZOOM.get(lab._level, 0))
	var g := lab.glass_rect()
	var gs := zoom.glass_on_screen
	var room := zoom.room_rect()
	var smaller := (g.size * float(z - 1)).min(Vector2(LabZoom.W, LabZoom.H))
	var covers := Rect2(0, 0, LabZoom.W, LabZoom.H).intersection(zoom.board_rect).is_equal_approx(Rect2(0, 0, LabZoom.W, LabZoom.H))
	_ok("%s: landed at the %s's zoom %d, the room one picture %s at it, the glass %s centred (at %d it would be %s, too small for the board's 908x488)" % [tag,
		lab._level, z, room, gs, z - 1, g.size * float(z - 1)],
		z >= 2 and is_equal_approx(zoom.cam_scale(), float(z)) and room.size.is_equal_approx(LabScene.PANEL * float(z))
		and gs.size.is_equal_approx(g.size * float(z)) and gs.get_center().distance_to(Vector2(480, 270)) <= 0.5
		and gs.position == gs.position.round() and gs.is_equal_approx(zoom.to_screen(g))
		and (smaller.x < LabZoom.GLASS.size.x or smaller.y < LabZoom.GLASS.size.y))
	var bad := zoom.check()
	_ok("%s: the board's glass is inside the lab's glass on screen (%s)" % [tag, "clean" if bad.is_empty() else "; ".join(bad)],
		not Array(bad).any(func(b: String) -> bool: return b.begins_with("the board's glass")))
	_ok("%s: the glass %s the window, and the room under the pages is %s (room %s, its frame %s, the sign-on %s)" % [tag,
		"covers" if covers else "sits in its bezel in", "not drawn" if covers else "drawn round it",
		zoom._room.visible, zoom._frame.visible, zoom._screen.visible],
		zoom._room.visible == (not covers) and zoom._life.visible == (not covers) and zoom._frame.visible == (not covers) and not zoom._screen.visible)
	var login := st._login
	var lb := login.check()
	_ok("%s: the screen it carried in says SIGNING IN, and passes the box test (%s)" % [tag, "clean" if lb.is_empty() else "; ".join(lb)],
		login.state == LabLogin.SIGNING and login.leaves.any(func(l: Array) -> bool: return str(l[0]).contains("SIGNING IN")) and lb.is_empty())
	var cut := _cut_at_landing(st)
	var on_screen := Rect2(zoom.to_screen(Rect2(lab.win_rect().position + Vector2(login.safe.position), Vector2(login.safe.size))))
	_ok("%s: landed, every box of SIGNING IN is inside 960x540 (%s; its area %s on screen)" % [tag, "all in" if cut.is_empty() else "; ".join(cut), on_screen],
		cut.is_empty() and Rect2(0, 0, LabZoom.W, LabZoom.H).encloses(on_screen))
	# THE DEN'S THIN BEZEL: where the glass leaves no more than a few px of the
	# room at an edge, the board's ground covers the window whole
	var gaps := [gs.position.x, gs.position.y, LabZoom.W - gs.end.x, LabZoom.H - gs.end.y]
	var thin: bool = gaps.all(func(v: float) -> bool: return v <= LabZoom.THIN)
	_ok("%s: the board's ground %s (glass %s, ground %s)" % [tag, "covers the window, the bezel only a few px" if thin else "lies on the glass", gs, zoom.board_rect],
		zoom.board_rect.is_equal_approx(gs) if not thin else zoom.board_rect.encloses(Rect2(-16, -16, LabZoom.W + 32, LabZoom.H + 32)))


## THE MOVE ITSELF, animated (`Router.animate_in_harness`): the camera carries the deck's frame,
## the elevator and the HUD with the room, and a press, Esc or Tab mid-move does what it should.
## Why: docs/why/StationDeckTest.md#the-move-itself
func _camera_move(st: StationScreen, zoom: LabZoom, tag: String) -> void:
	var hud: Control = Router.hud
	var was_anim := Router.animate_in_harness
	Router.animate_in_harness = true
	var mid := ZoomLadder.LAB_ZOOM_S * 0.4
	# (where the elevator and the HUD stand at rest, against the room)
	var o0 := st._lab.get_global_transform().origin
	var plate := st.lab_frame()
	var f0 := plate.get_global_rect()
	var rail0 := st._rail.position
	var hud0 := hud.position
	var rail_gap := f0.position.x - st._rail.get_global_rect().end.x
	var hud_gap := f0.position.y - hud.get_global_rect().end.y
	# (the room's picture and the deck's frame on screen where they stand)
	var still := func() -> bool:
		var s0 := st._lab.get_global_transform().get_scale().x
		var rest := Rect2(o0.round(), (o0 + LabScene.PANEL * s0).round() - o0.round())
		return zoom.to_screen(Rect2(Vector2.ZERO, LabScene.PANEL)) == rest and zoom.frame_rect() == f0
	# IN: on the press the deck's plate is whole and nothing of the camera is
	# drawn; the camera is off within two frames of it, the frame it draws on
	# the plate's own px (no pop at the hand-over)
	var gat := st._glass_press.get_global_rect().get_center()
	st._glass_press.notification(Control.NOTIFICATION_MOUSE_ENTER)
	var target := GameShell.input_target(_tree)
	var mv := InputEventMouseMotion.new()
	mv.position = gat
	mv.global_position = gat
	target.push_input(mv)
	await _tree.process_frame
	for pressed: bool in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		mb.position = gat
		mb.global_position = gat
		target.push_input(mb)
	var press_ok := zoom.is_open() and is_equal_approx(plate.self_modulate.a, 1.0) and not zoom._frame.visible and not zoom._room.visible
	# (the frames the camera has had since the press, counted from the first)
	await _tree.process_frame
	var off_n := 1
	while off_n < 10 and zoom.is_open() and still.call():
		off_n += 1
		await _tree.process_frame
	var hand := zoom.frame_rect()
	var hand_ok := zoom._frame.visible and plate.self_modulate.a == 0.0 \
		and absf(hand.position.x - f0.position.x) <= 2.0 and absf(hand.position.y - f0.position.y) <= 2.0 \
		and absf(hand.end.x - f0.end.x) <= 2.0 and absf(hand.end.y - f0.end.y) <= 2.0
	st._glass_press.notification(Control.NOTIFICATION_MOUSE_EXIT)
	_ok("%s, animated: on the press the deck's plate is whole and the camera draws nothing (%s); the camera is off %d frame(s) after it (at most 2), its frame on the plate's px as it takes over (%s, %s from %s)" % [tag,
		press_ok, off_n, hand_ok, hand, f0],
		press_ok and off_n <= 2 and not still.call() and hand_ok)
	await _until(func() -> bool: return zoom._at >= ZoomLadder.LAB_ZOOM_S * 0.15)
	var moving := zoom.is_open() and not zoom.landed() and zoom._at > 0.0
	var rm := zoom.room_rect()
	var fr := zoom.frame_rect()
	var k := zoom.cam_scale() / st._lab.get_global_transform().get_scale().x
	var rg := fr.position.x - st._rail.get_global_rect().end.x
	var hg := fr.position.y - hud.get_global_rect().end.y
	_ok("%s, animated: early in the move the deck's frame rides with the room, one picture at its scale (frame %s from %s, x%.3f; its margin %.1f, at rest %.1f), the plate itself hidden (%.2f)" % [tag,
		fr, f0, k, rm.position.x - fr.position.x, o0.x - f0.position.x, plate.self_modulate.a],
		moving and zoom._frame.visible and plate.self_modulate.a == 0.0
		and absf(fr.size.x - f0.size.x * k) <= 1.0 and absf(fr.size.y - f0.size.y * k) <= 1.0
		and absf((rm.position.x - fr.position.x) - (o0.x - f0.position.x) * k) <= 1.0
		and absf((rm.position.y - fr.position.y) - (o0.y - f0.position.y) * k) <= 1.0)
	_ok("%s, animated: early in the move the elevator and the HUD ride the frame's edges out, whole, over the zoom (rail gap %.1f, at rest %.1f, x %.0f from %.0f, alpha %.2f, z %d; HUD gap %.1f, at rest %.1f, alpha %.2f, z %d)" % [tag,
		rg, rail_gap, st._rail.position.x, rail0.x, st._rail.modulate.a, st._rail.z_index, hg, hud_gap, hud.modulate.a, hud.z_index],
		moving and st._rail.position.x < rail0.x and absf(rg - rail_gap) <= 1.0 and st._rail.z_index == 2
		and (st._rail.modulate.a > 0.98 or st._rail.get_global_rect().end.x <= 0.0)
		and (hud.position.y < hud0.y or fr.position.y >= f0.position.y) and absf(hg - hud_gap) <= 1.0 and hud.z_index == 2)
	await _until(func() -> bool: return zoom._at >= mid)
	moving = zoom.is_open() and not zoom.landed() and zoom._at > 0.0
	_ok("%s, animated: mid-move the HUD and the rail are out of the window, and the sign-on rides in on the glass (HUD %.2f, rail %.2f, the screen %s %s, at %.2f of %.2f)" % [tag,
		hud.modulate.a, st._rail.modulate.a, st._login.state, zoom._screen.visible, zoom._at, zoom._goal],
		moving and (hud.modulate.a < 0.02 or hud.get_global_rect().end.y <= 0.0)
		and (st._rail.modulate.a < 0.02 or st._rail.get_global_rect().end.x <= 0.0) and zoom._screen.visible
		and st._login.state == LabLogin.SIGNING and is_equal_approx(st._screen_pic.modulate.a, 1.0))
	# THE SCREEN'S OWN EFFECTS GO WITH THE CHROME (its snow flashed on the bare
	# glass), and THE CAMERA IS ONE PICTURE: the room at one scale between the
	# room's own and the lab's zoom, the glass at that same scale in it
	var fxl := st._lab.fx_layer()
	var s := zoom.cam_scale()
	var z := float(LabZoom.ZOOM.get(st._lab._level, 0))
	var g := st._lab.glass_rect()
	var gm := zoom.to_screen(g)
	var room := zoom.room_rect()
	_ok("%s, animated: mid-move the screen's own effects are gone (screen %.2f, hushed %s), the lamps held steady (%s), the deck's frame drawn with the room (%s), and the room is one picture at %.3f (room %s, its glass %s, %.3f of it)" % [tag,
		fxl.modulate.a, st._lab._glass.hushed, st._lab.lamps_held, zoom._frame.visible, s, room, gm, gm.size.x / g.size.x],
		fxl.modulate.a < 0.02 and st._lab._glass.hushed and st._lab.lamps_held and zoom._frame.visible and zoom._room.visible
		and s > 1.0 and s < z and room.size.is_equal_approx(LabScene.PANEL * s)
		and absf(gm.size.x / g.size.x - s) <= 1.0 / g.size.x and absf(gm.size.y / g.size.y - s) <= 1.0 / g.size.y
		and room.position == room.position.round())
	# Esc mid-move turns it round, and no pause menu opens
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	GameShell.input_target(_tree).push_input(esc)
	await _tree.process_frame
	var menu: Variant = _tree.current_scene.get("_menu") if _tree.current_scene != null else null
	_ok("%s, animated: Esc on the way in turns the camera round (goal %.2f, still moving %s), opens no menu (%s), and the glass keeps SIGNING IN while it moves (%s)" % [tag,
		zoom._goal, zoom.visible and zoom._at > 0.0, menu, st._login.state],
		zoom._goal == 0.0 and zoom.visible and zoom._at > 0.0 and menu == null and st._login.state == LabLogin.SIGNING)
	# (on the way out, frame by frame: neither the elevator nor the HUD ever
	# over the frame, and both in their places on the frame the camera rests,
	# the deck's plate whole there and nothing of the camera's frame left)
	var over := 0.0
	var home_at := -1.0
	# (frames the Lab is still up, taking the input, with the camera's
	# picture already the room's own)
	var still_n := 0
	var t0 := Time.get_ticks_msec()
	while zoom.visible and Time.get_ticks_msec() - t0 < 8000:
		if still.call():
			still_n += 1
		var r2 := zoom.frame_rect()
		if st._rail.modulate.a > 0.0:
			over = maxf(over, st._rail.get_global_rect().end.x - r2.position.x)
		if hud.modulate.a > 0.0:
			over = maxf(over, hud.get_global_rect().end.y - r2.position.y)
		await _tree.process_frame
	if st._rail.position == rail0 and hud.position == hud0:
		home_at = 0.0
	var plate_home := is_equal_approx(plate.self_modulate.a, 1.0) and not zoom._frame.visible and not zoom._room.visible
	_ok("%s, animated: out again, on the frame the camera rests the deck's plate is whole and the camera's frame gone (%s, %.2f), the Lab down on that same frame (still with it up: %d frames)" % [tag,
		plate_home, plate.self_modulate.a, still_n], plate_home and still_n == 0)
	_ok("%s, animated: out again, the elevator and the HUD ride back in, never over the frame (by at most %.1f px), in their places once the camera rests (%s), and as they were (HUD %.2f z %d, rail %.2f z %d, at %s)" % [tag,
		over, home_at >= 0.0, hud.modulate.a, hud.z_index, st._rail.modulate.a, st._rail.z_index, st._rail.position],
		not zoom.is_open() and is_equal_approx(hud.modulate.a, 1.0) and is_equal_approx(st._rail.modulate.a, 1.0)
		and over <= 0.5 and home_at >= 0.0 and st._rail.position == rail0 and hud.position == hud0
		and hud.z_index == 0 and st._rail.z_index == 0 and not st._lab_lift)
	await Harness.frames(_tree, 2)
	_ok("%s, animated: out again, the screen's effects back on its logo, the lamps free (screen %.2f, hushed %s, lamps held %s, the screen %s)" % [tag,
		st._lab.fx_layer().modulate.a, st._lab._glass.hushed, st._lab.lamps_held, st._login.state],
		is_equal_approx(st._lab.fx_layer().modulate.a, 1.0) and not st._lab._glass.hushed and not st._lab.lamps_held
		and st._login.state == LabLogin.LOGO)
	# IN AGAIN: a click mid-move lands it, and goes no further (it is where
	# the AUGMENT tab will be)
	await _click(st._glass_press)
	st._glass_press.notification(Control.NOTIFICATION_MOUSE_EXIT)
	await _until(func() -> bool: return zoom._at >= mid)
	var tab_at: Vector2 = (zoom.tab_buttons[&"augment"] as Control).get_global_rect().get_center()
	var at_click := zoom._at
	await _click_at(tab_at)
	await _tree.process_frame
	var jumped := zoom.landed()
	var both := 0.0
	t0 = Time.get_ticks_msec()
	while not (zoom.landed() and zoom.view.modulate.a >= 1.0) and Time.get_ticks_msec() - t0 < 8000:
		both = maxf(both, minf(zoom.signon_alpha(), zoom.view.modulate.a))
		await _tree.process_frame
	await Harness.frames(_tree, 2)
	_ok("%s, animated: a click mid-move is eaten and the camera goes on, no jump (at %.2f, landed the next frame %s), landing by itself on RESEARCH (landed %s, the page %s, not AUGMENT)" % [tag,
		at_click, jumped, zoom.landed(), zoom.tab],
		not jumped and zoom.landed() and zoom.tab == &"research")
	_ok("%s, animated: the sign-on is gone before the pages come up (both showing at once, at most %.3f)" % [tag, both], both < 0.1)
	# LANDED, the chrome stays gone (frames on: where there is a berth the
	# yard's edge sets the rail's alpha every frame, and put it back whole)
	await Harness.frames(_tree, 4)
	_ok("%s, animated: landed, frames on, the HUD and the rail stay gone (HUD %.2f, rail %.2f)" % [tag, hud.modulate.a, st._rail.modulate.a],
		zoom.landed() and hud.modulate.a < 0.02 and st._rail.modulate.a < 0.02)
	# nothing drawn for nothing under the pages: the sign-on is hidden, and
	# the room and its frame too where the glass covers the window
	var covers := Rect2(0, 0, LabZoom.W, LabZoom.H).intersection(zoom.glass_on_screen).is_equal_approx(Rect2(0, 0, LabZoom.W, LabZoom.H))
	_ok("%s, animated: landed, the sign-on under the pages is hidden, the room and its frame %s (room %s, frame %s, sign-on %s)" % [tag,
		"too (the glass covers the window)" if covers else "drawn round the glass", zoom._room.visible, zoom._frame.visible, zoom._screen.visible],
		zoom.landed() and zoom._room.visible == (not covers) and zoom._frame.visible == (not covers) and not zoom._screen.visible)
	# OUT, with a click on the glass mid-move: it lands out, and the Lab stays shut
	await _click(zoom.leave_button)
	await _until(func() -> bool: return zoom._at <= ZoomLadder.LAB_ZOOM_S * 0.5)
	var glass_at := st._bench_clip.get_global_rect().get_center()
	await _click_at(glass_at)
	await _tree.process_frame
	var cut_out := not zoom.visible
	t0 = Time.get_ticks_msec()
	while zoom.visible and not still.call() and Time.get_ticks_msec() - t0 < 8000:
		await _tree.process_frame
	# THE CAMERA AT REST, A CLICK ON THE ELEVATOR TWO FRAMES ON IS TAKEN (the
	# press reaches the viewport on the second frame after the rest)
	var deck := &""
	for d: StringName in [&"services", &"hold", &"stock", &"work"]:
		if deck == &"" and (st._tabs[d] as Button).is_visible_in_tree():
			deck = d
	var plate_out := is_equal_approx(plate.self_modulate.a, 1.0) and not zoom._frame.visible
	await _tree.process_frame
	await _click(st._tabs[deck] as Button)
	(st._tabs[deck] as Button).notification(Control.NOTIFICATION_MOUSE_EXIT)
	var took := st._tab == deck
	_ok("%s, animated: out, the deck's plate whole on the frame the camera rests (%s), and a click on the elevator two frames on is taken (%s: on %s)" % [tag,
		plate_out, deck, st._tab], plate_out and took)
	await _until(func() -> bool: return not st.deck_changing())
	await Harness.frames(_tree, 2)
	_ok("%s, animated: a click on the glass on the way out is eaten, the camera goes on out (no jump: %s) and opens nothing (open %s, shown %s, HUD %.2f)" % [tag,
		not cut_out, zoom.is_open(), zoom.visible, hud.modulate.a],
		not cut_out and not zoom.is_open() and not zoom.visible and is_equal_approx(hud.modulate.a, 1.0))
	(st._tabs[&"bench"] as Button).pressed.emit()
	await _until(func() -> bool: return not st.deck_changing())
	await Harness.frames(_tree, 2)
	# TAB, ANIMATED, with the camera in: it goes out at three times the pace (it
	# moves, never cuts) and holds the key for Main till it is out (taken back
	# here, or the test would leave the station)
	zoom.open(&"research")
	zoom.finish()
	await Harness.frames(_tree, 2)
	var tab_a := InputEventKey.new()
	tab_a.keycode = KEY_TAB
	tab_a.physical_keycode = KEY_TAB
	tab_a.pressed = true
	zoom._input(tab_a)
	await _tree.process_frame
	var tab_moving := zoom.visible and zoom._at > 0.0 and zoom._goal == 0.0 and zoom._rate == 3.0 and zoom._then_key != null
	zoom._then_key = null
	t0 = Time.get_ticks_msec()
	while zoom.visible and Time.get_ticks_msec() - t0 < 8000:
		await _tree.process_frame
	_ok("%s, animated: Tab with the camera in takes it out moving, at 3x (moving %s), then lets the key go on (out %s)" % [tag, tab_moving, not zoom.visible],
		tab_moving and not zoom.visible and not zoom.is_open())
	# TAB with the camera in: out at once, the chrome back, the key left for Main
	Router.animate_in_harness = false
	zoom.open(&"research")
	await Harness.frames(_tree, 1)
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


## THE ELEVATOR'S RIDE BETWEEN DECKS, animated (Jon, Nov 5: "a smoother transition with the
## elevator"; the review: a dip to black is still a cut).
## Why: docs/why/StationDeckTest.md#the-elevators-ride-between-decks
func _deck_ride(st: StationScreen, tag: String) -> void:
	var was_anim := Router.animate_in_harness
	Router.animate_in_harness = true
	var lab_page := st._pages[&"bench"] as Control
	var yard := st._pages[&"services"] as Control
	var hold := st._pages[&"hold"] as Control
	var body := lab_page.get_parent() as Control
	var span := body.size.y + float(StationScreen.DECK_SLAB)
	var clip0 := body.clip_contents
	(st._tabs[&"services"] as Button).pressed.emit()
	var secs := st._ride_s
	await _tree.process_frame
	_ok("%s, animated: SHIPYARD from the Lab puts both decks in one shaft, neither taking clicks, the panel clipped (Lab %s y %.0f, yard %s y %.0f, span %.0f, ride %.2f s)" % [tag,
		lab_page.visible, lab_page.position.y, yard.visible, yard.position.y, span, secs],
		st._tab == &"services" and lab_page.visible and yard.visible and st.deck_changing() and body.clip_contents
		and is_equal_approx(lab_page.position.y - yard.position.y, span)
		and lab_page.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED
		and yard.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED)
	var rigid := true
	var down_only := true
	var last := lab_page.position.y
	var scaled := false
	var frames := 0
	while st.deck_changing() and frames < 600:
		if not is_equal_approx(lab_page.position.y - yard.position.y, span):
			rigid = false
		if lab_page.position.y < last:
			down_only = false
		last = lab_page.position.y
		if lab_page.scale != Vector2.ONE or yard.scale != Vector2.ONE:
			scaled = true
		frames += 1
		await _tree.process_frame
	await Harness.frames(_tree, 1)
	_ok("%s, animated: going up, the shaft moves down as one (rigid %s, one way %s, scaled %s, %d frames), and at the car's arrival only the yard shows, in its place, taking clicks, the clip as it was (Lab %s, yard y %.0f)" % [tag,
		rigid, down_only, scaled, frames, lab_page.visible, yard.position.y],
		rigid and down_only and not scaled and frames >= 3 and not lab_page.visible and yard.visible
		and yard.position.y == 0.0 and lab_page.position.y == 0.0 and body.clip_contents == clip0
		and yard.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_INHERITED
		and lab_page.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_INHERITED)
	# ONE FLOOR DOWN takes at least DECK_MIN_S (a 0.24 s hop read as a blink)
	(st._tabs[&"hold"] as Button).pressed.emit()
	var n1 := 0
	var t1 := 0.0
	while st.deck_changing() and n1 < 600:
		n1 += 1
		await _tree.process_frame
		t1 += st.get_process_delta_time()
	_ok("%s, animated: one floor (SHIPYARD to EXCHANGE) rides for at least %.2f s (%.2f s, %d frames)" % [tag,
		StationScreen.DECK_MIN_S, t1, n1],
		t1 >= StationScreen.DECK_MIN_S - 0.02)
	(st._tabs[&"services"] as Button).pressed.emit()
	await _until(func() -> bool: return not st.deck_changing(), 4000)
	# A SECOND PRESS MID-RIDE takes over from where the shaft stands: the yard,
	# still on screen, does not jump
	(st._tabs[&"bench"] as Button).pressed.emit()
	await Harness.frames(_tree, 3)
	var y_was := yard.position.y
	# (and the glass cannot be pressed while the Lab rides in)
	st._open_lab(&"research")
	var opened := st._lab_zoom.is_open()
	(st._tabs[&"hold"] as Button).pressed.emit()
	var y_now := yard.position.y
	await _tree.process_frame
	var shown := 0
	for k in st._pages:
		if (st._pages[k] as Control).visible:
			shown += 1
	_ok("%s, animated: the glass is not pressed while the Lab rides in (%s); a floor pressed mid-ride takes over from where the yard stands (y %.0f then %.0f, decks shown %d, the Lab %s, EXCHANGE %s, tab %s)" % [tag,
		opened, y_was, y_now, shown, lab_page.visible, hold.visible, st._tab],
		not opened and shown == 2 and yard.visible and hold.visible and not lab_page.visible and st._tab == &"hold"
		and st.deck_changing() and y_was < 0.0 and is_equal_approx(y_now, y_was)
		and is_equal_approx(hold.position.y - yard.position.y, span))
	await _until(func() -> bool: return not st.deck_changing(), 4000)
	Router.animate_in_harness = false
	(st._tabs[&"bench"] as Button).pressed.emit()
	var at_rest := true
	for k2 in st._pages:
		if (st._pages[k2] as Control).position.y != 0.0:
			at_rest = false
	_ok("%s: unanimated, the deck changes on the press (Lab %s, every deck in its place %s)" % [tag, lab_page.visible, at_rest],
		lab_page.visible and not hold.visible and at_rest and not st.deck_changing())
	await Harness.frames(_tree, 3)
	Router.animate_in_harness = was_anim


## EVERY ELEVATOR CHOICE IS THE SLIDE (Jon, Nov 5, round three: "The slide can be the main
## transition for every elevator choice").
## Why: docs/why/StationDeckTest.md#every-elevator-choice-is-the-slide
func _every_ride(dev: int) -> void:
	var tag := "%s, every ride" % String(MapGen.Development.keys()[dev]).to_lower()
	var st := await _dock(_station(dev, false, 9100 + dev))
	if not _ok("%s: the station is up" % tag, st != null):
		return
	var was_anim := Router.animate_in_harness
	var was_scale := Engine.time_scale
	var ids: Array[StringName] = []
	for row in StationScreen.DECKS:
		ids.append(row[0])
	var body := (st._pages[&"bench"] as Control).get_parent() as Control
	var span := body.size.y + float(StationScreen.DECK_SLAB)
	var bad: Array[String] = []
	var rides := 0
	var lamp_max := -1.0
	for a in ids:
		for b in ids:
			if a == b:
				continue
			Router.animate_in_harness = false
			st._show_tab(a)
			await _tree.process_frame
			Router.animate_in_harness = true
			# (twice the speed: twenty rides a level; a frame is then the
			# ride's longest step, `RIDE_STEP_S`)
			Engine.time_scale = 2.0
			var from := st._pages[a] as Control
			var to := st._pages[b] as Control
			var down := ids.find(b) > ids.find(a)
			var gap := span if down else -span
			var first_board := b == &"work" and not Router.powered.has(&"work")
			var clip0 := [from.clip_contents, to.clip_contents, from.z_index, to.z_index]
			(st._tabs[b] as Button).pressed.emit()
			var why := ""
			if not (st.deck_changing() and from.visible and to.visible and st._deck_slab != null and st._deck_dark == null):
				why = "no slide (changing %s, from %s, to %s, slab %s, dark %s)" % [st.deck_changing(), from.visible, to.visible, st._deck_slab != null, st._deck_dark != null]
			elif not is_equal_approx(to.position.y - from.position.y, gap):
				why = "the deck gone to on the wrong side (%.0f, %.0f wanted)" % [to.position.y - from.position.y, gap]
			var secs := st._deck_secs
			var frames := 0
			var t := 0.0
			var rigid := true
			var one_way := true
			var y_last := from.position.y
			var step_max := 0.0
			while st.deck_changing() and frames < 900:
				await _tree.process_frame
				t += st.get_process_delta_time()
				if not st.deck_changing():
					break
				frames += 1
				# (each deck clipped to itself, and the lower drawn over the upper:
				# the PROMENADE's page runs on 500 px past the panel, over the yard)
				if not is_equal_approx(to.position.y - from.position.y, gap) or not from.visible or not to.visible 						or not from.clip_contents or not to.clip_contents or (to.z_index > from.z_index) != down:
					rigid = false
				if (from.position.y - y_last) * (1.0 if down else -1.0) > 0.0:
					one_way = false
				step_max = maxf(step_max, absf(from.position.y - y_last))
				y_last = from.position.y
				# (on the ride's own clock: a stalled frame holds the ride)
				if first_board and st._deck_fade.get_total_elapsed_time() < secs - 0.3:
					lamp_max = maxf(lamp_max, st._board_lamp.level())
			# (no frame moves the shaft more than a RIDE_STEP_S step at the
			# shortest ride's top speed: a long frame does not jump it)
			var step_cap := span * PI / 2.0 * StationScreen.RIDE_STEP_S / StationScreen.DECK_MIN_S + 2.0
			if why == "" and (frames < 4 or not rigid or not one_way or step_max > step_cap):
				why = "the shaft (frames %d over %.3f s, rigid %s, one way %s, a frame's step %.0f px of %.0f)" % [frames, t, rigid, one_way, step_max, step_cap]
			await _tree.process_frame
			var shown := 0
			for k in st._pages:
				if (st._pages[k] as Control).visible:
					shown += 1
			if why == "" and not (st._tab == b and to.visible and shown == 1 and to.position.y == 0.0
					and from.position.y == 0.0 and st._deck_slab == null
					and [from.clip_contents, to.clip_contents, from.z_index, to.z_index] == clip0
					and to.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_INHERITED
					and from.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_INHERITED):
				why = "not at rest after (tab %s, shown %d, y %.0f)" % [st._tab, shown, to.position.y]
			if why != "":
				bad.append("%s to %s: %s" % [a, b, why])
			rides += 1
	Engine.time_scale = was_scale
	_ok("%s: all %d rides between the five decks, up and down, are the slide (%s)" % [tag, rides, "all" if bad.is_empty() else "; ".join(bad)],
		rides == 20 and bad.is_empty())
	_ok("%s: the board's tubes stay dark riding in till the car is nearly in (level %.2f)" % [tag, lamp_max],
		lamp_max == 0.0)
	# THE FALLBACK: the dip through the dark
	StationScreen.deck_move = &"dip"
	(st._tabs[&"stock"] as Button).pressed.emit()
	var dipped := st.deck_changing() and st._deck_dark != null and st._deck_slab == null
	await _until(func() -> bool: return not st.deck_changing(), 4000)
	StationScreen.deck_move = &"slide"
	_ok("%s: deck_move &\"dip\" dips through the dark instead (%s), and lands (tab %s)" % [tag, dipped, st._tab],
		dipped and st._tab == &"stock" and (st._pages[&"stock"] as Control).visible and not st.deck_changing())
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
	await Harness.frames(_tree, 2)
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
		await Harness.frames(_tree, 2)
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
				await Harness.frames(_tree, 1)
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
	await Harness.frames(_tree, 2)
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
	await Harness.frames(_tree, 2)
	var pages := aug._pages.size()
	var fails2: Array[String] = []
	for pg2 in pages:
		if pg2 > 0:
			await _click(aug.more_button)
			await Harness.frames(_tree, 1)
		for f2 in zoom.check():
			fails2.append("page %d: %s" % [aug.page + 1, f2])
	_ok("%s: %d parts run onto %d pages, MORE turns them, and each passes the box test (%s)" % [tag, Run.installed.size() + _held().size(),
		pages, "clean" if fails2.is_empty() else "; ".join(fails2.slice(0, 4))], fails2.is_empty() and (pages > 1) == aug.more_button.visible)


## The augmented part on STRIP: each of its affixes in hand passes the box
## test, the key reads STRIP, and the bill is 2 DATA and this level's credits.
func _strip_view(aug: LabAugment, m: ModuleData, dev: int) -> bool:
	aug.pick_part(m)
	await Harness.frames(_tree, 1)
	var ok := aug.mode == &"strip" and aug._affs.size() == m.affixes.size()
	for k in aug._affs.size():
		aug.pick_affix(k)
		await Harness.frames(_tree, 1)
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
	await Harness.frames(_tree, 2)
	var key := aug.commit_button
	for i in 30:
		Sig.resources_changed.emit()
		if i % 10 == 0:
			await Harness.frames(_tree, 1)
	await Harness.frames(_tree, 2)
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
	await Harness.frames(_tree, 2)
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
	await Harness.frames(_tree, 2)
	_ok("%s: picked again, it opens on STRIP, never a second augment" % tag, aug.mode == &"strip" and aug.commit_button.label == "STRIP")
	# the Lab's own affix picked, and it last on the part: the rolled one first
	var at_lab := -1
	for i in aug._affs.size():
		if aug._affs[i].name == a.name:
			at_lab = i
	aug.pick_affix(at_lab)
	await Harness.frames(_tree, 1)
	var data1 := Run.data
	var cr1 := Run.credits
	await _click(aug.commit_button)
	await Harness.frames(_tree, 2)
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
	await Harness.frames(_tree, 2)
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
	await Harness.frames(_tree, 1)
	await _click_at(board.get_global_transform() * Vector2(board._nodes[Vector2i(1, 0)]))
	_ok("%s: a click on CORE's first step puts it on the strip, with BUY" % tag,
		board.pick == Vector2i(1, 0) and board.buy_button.visible)
	var buy := board.buy_button
	var key: Button = st._glass_press
	for i in 30:
		Sig.resources_changed.emit()
		if i % 10 == 0:
			await Harness.frames(_tree, 1)
	await Harness.frames(_tree, 2)
	_ok("%s: BUY and the glass's key are the same objects after 30 refreshes" % tag,
		is_instance_valid(buy) and board.buy_button == buy and buy.visible and buy.get_parent() == board
		and is_instance_valid(key) and st._glass_press == key)
	# BUY'S OWN SOUND (Jon's pick C15, Nov 9): lab_research_buy once on the press, never fabricate
	var was_taping := Audio.taping
	Audio.taping = true
	Audio.tape.clear()
	await _click(buy)
	await Harness.frames(_tree, 2)
	var heard: Array = Audio.tape.map(func(r: Array) -> String: return String(r[0]))
	Audio.taping = was_taping
	_ok("%s: BUY sounds lab_research_buy once and no fabricate (%s)" % [tag, heard],
		heard.count("lab_research_buy") == 1 and heard.count("fabricate") == 0)
	_ok("%s: BUY spends 4 DATA and runs CORE's first step (DATA %d, owned %s, the strip on %s)"
		% [tag, Run.data, str(Run.board_owned), board.bought],
		Run.data == 36 and Run.board_owned[1] == 1 and board.bought == Vector2i(1, 0) and zoom._note == "-4")
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
	await Harness.frames(_tree, 2)
	await _click(board.buy_button)
	await Harness.frames(_tree, 2)
	var bad2 := zoom.check()
	_ok("%s: DATA short, BUY is there and dead, the strip says YOU HAVE 3 DATA, a click buys nothing, and it fits (%s)" % [tag,
		"clean" if bad2.is_empty() else "; ".join(bad2)],
		board.buy_button.visible and board.buy_button.disabled and board.buy_button == buy
		and board.leaves.any(func(l: Array) -> bool: return l[0] == "YOU HAVE 3 DATA")
		and Run.data == 3 and Run.board_owned[0] == 0 and bad2.is_empty())


## THE LAB'S REMINDER (Jon's S1A, Nov 8): seen from another deck, the Laboratory's line reads
## "DATA 9" in COLD under LAB_REMIND and "SPEND 10 DATA" in EMBER at it.
func _reminder(st: StationScreen, tag: String) -> void:
	var note := st._deck_note.get(&"bench") as Label
	var was := Run.data
	st._show_tab(&"services")
	await Harness.frames(_tree, 2)
	var seen: Array = []
	for d in [StationScreen.LAB_REMIND - 1, StationScreen.LAB_REMIND]:
		Run.data = d
		Sig.resources_changed.emit()
		await Harness.frames(_tree, 1)
		seen.append([note.text if note != null else "", note != null and note.get_theme_color(&"font_color") == UITheme.EMBER])
	Run.data = was
	Sig.resources_changed.emit()
	st._show_tab(&"bench")
	await Harness.frames(_tree, 2)
	_ok("%s: the Lab's line from the Shipyard reads %s" % [tag, seen],
		seen == [["DATA 9", false], ["SPEND 10 DATA", true]])


## THE SAME BOARD AT A SECOND STATION of the run: the same steps where they
## were and every word where it was, a station two levels up.
func _second_station() -> void:
	var here := _station(MapGen.Development.OUTPOST, false, 9100)
	var st := await _dock(here)
	if not _ok("second station: the first is up", st != null and await _open(st, &"bench")):
		return
	await _reminder(st, "second station")
	Run.board_owned[0] = 1
	Run.board_owned[2] = 2
	Run.data = 16
	st.lab_zoom().open(&"research")
	st.lab_zoom().board.pick = Vector2i(1, 0)
	st.lab_zoom().board.refresh()
	await Harness.frames(_tree, 3)
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
	await Harness.frames(_tree, 3)
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

