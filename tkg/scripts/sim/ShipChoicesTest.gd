extends Node

## The choices on your own ship (`ShipChoices`, Jon, Nov 15), on the real LOCAL with the HUD:
## `-- sheet=ShipChoicesTest` (headless, `--fixed-fps 60`). `report` lists every collision.
## Why: docs/why/ShipChoices.md#on-your-ship

var _tree: SceneTree
var h := Harness.new()
var _sc: SectorScreen = null
var _d: LocalEventDrawer = null


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tree = get_tree()
	await Harness.frames(_tree, 2)
	_report("report" in OS.get_cmdline_user_args())
	_switch()
	LocalEventDrawer.layout = &"ship"
	Router.animate_in_harness = true
	Rng.forced = 1
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n := _node()
	n.options.assign([&"dropped_load", _stays_put(), &"slipping_orbit", &"mine_drift", &"salvage_rights", &"still_under_warranty", _crowded()])
	Router.show_local()
	await Harness.frames(_tree, 120)
	_sc = Router.current as SectorScreen
	_d = _sc.get("_events") if _sc != null else null
	if not _ok("LOCAL is up with its event drawer", _d != null):
		return _end()
	SkillCheck.forced = int(SkillCheck.Band.MET)
	await _beat_and_click(n)
	await _not_now()
	await _too_late(n)
	await _loot()
	await _warns()
	await _hulls(n)
	await _sweep(n)
	await _arrivals(n)
	await _same_as_the_card()
	_end()


func _end() -> void:
	SkillCheck.forced = -1
	h.verdict("shipchoicestest")
	_tree.quit(h.code())


func _node() -> MapGen.MapNode:
	var idx := 11
	var n: MapGen.MapNode = Run.map[idx]
	Run.at = idx
	n.visited = true
	OptionTable.ensure(n)
	SectorScreen._approached_at = idx
	return n


## An encounter with no walk-away of its own, so NOT NOW holds the bow.
func _stays_put() -> StringName:
	for o in OptionTable.all():
		var cs: Array = o.get("choices", [])
		if cs.size() >= 2 and not ShipParts.walks_away(cs):
			return StringName(o.id)
	return &""


## The authored encounter with the most choices (the most crowded ship).
func _crowded() -> StringName:
	var best: Dictionary = {}
	for o in OptionTable.all():
		if (o.get("choices", []) as Array).size() > (best.get("choices", []) as Array).size():
			best = o
	return StringName(best.id)


# --------------------------------------------------------------- the part report

## Every encounter's choices on parts: how many have two that want the same part (and, with
## NOT NOW on the bow, how many more a walk-away choice adds), with examples.
func _report(all: bool) -> void:
	var clash := 0
	var total := 0
	var shown := 0
	var not_now := 0
	var by_part := {}
	for o in OptionTable.all():
		var choices: Array = o.get("choices", [])
		if choices.is_empty():
			continue
		total += 1
		if not ShipParts.walks_away(choices):
			not_now += 1
		var cl := ShipParts.collisions(choices)
		var parts := ShipParts.assign(choices, not ShipParts.walks_away(choices))
		for p in parts:
			by_part[p] = int(by_part.get(p, 0)) + 1
		if cl > 0:
			clash += 1
			if all or shown < 8:
				shown += 1
				var bits: Array = []
				for j in choices.size():
					bits.append("%s->%s(%s)" % [String((choices[j] as Dictionary).get("label", "?")), parts[j], ShipParts.wanted(choices[j])])
				print("  collide %s: %s" % [o.id, " | ".join(bits)])
	print("  parts report: %d encounters; %d have two choices wanting one part; %d have no walk-away and keep NOT NOW on the bow" % [total, clash, not_now])
	print("  where choices landed: %s" % by_part)
	_ok("every authored choice lands on a part (%d encounters)" % total, total > 0)


## The switch: off in exports and in every harness, on in an editor play run (F5) or when asked.
func _switch() -> void:
	var cases := [[["localeventtest"], true, &"band"], [[], true, &"ship"], [[], false, &"band"],
		[["shipchoices"], false, &"ship"], [["nolauncher", "seed", "123"], true, &"ship"],
		[["sheet=OutcomeTest"], true, &"band"], [["band"], true, &"band"]]
	var good := true
	for c: Array in cases:
		var got := LocalEventDrawer.default_layout(PackedStringArray(c[0]), bool(c[1]))
		if got != c[2]:
			good = false
			print("  switch: %s dev=%s gave %s" % [c[0], c[1], got])
	_ok("the switch: off in exports and harnesses, on in a play run or with -- shipchoices", good)
	# (a play run with the layout asked for is a player's run: the zoom ladder and the real doors)
	_ok("-- shipchoices alone is a play run, not a harness", not TestRun.active_for(PackedStringArray(["shipchoices"])) 		and not TestRun.active_for(PackedStringArray(["band"])) and TestRun.active_for(PackedStringArray(["shipchoices", "localeventtest"])))
	_ok("this harness ran with it off until it asked", LocalEventDrawer.default_layout(OS.get_cmdline_user_args(), DevMode.available) == &"band")


# --------------------------------------------------------------- the flow

func _ov() -> ShipChoices:
	return _d.get("_ship") as ShipChoices


func _tag(nm: String) -> ShipChoices.Tag:
	var ov := _ov()
	return ov.find_child(nm, false, false) as ShipChoices.Tag if ov != null else null


## A real click (motion, press, release) at the middle of `c`, through the window and the game's
## frame, as a hand makes it (straight into the game's viewport, a pointer never "enters" anything).
func _click(c: Control) -> void:
	var at := _win(UiRect.of(c).get_center())
	_move(c)
	await Harness.frames(_tree, 2)
	for down in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = down
		b.position = at
		b.global_position = b.position
		_tree.root.push_input(b)
		await Harness.frames(_tree, 1)


func _move(c: Control) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = _win(UiRect.of(c).get_center())
	mv.global_position = mv.position
	_tree.root.push_input(mv)


## A point of the game's 960x540 frame in the window.
func _win(at: Vector2) -> Vector2:
	var fr := GameShell.instance.get("_frame") as SubViewportContainer if GameShell.instance != null else null
	if fr == null:
		return at
	return fr.get_global_transform() * (at * float(fr.stretch_shrink))


func _open_settled(i: int) -> bool:
	_d.open(i)
	await Harness.frames(_tree, 3)
	if _d.text != null:
		_d.text.skip()
	var f := 0
	while _ov() != null and not (_ov().showing and float(_ov().get("_on_ship")) >= 1.0) and f < 300:
		await Harness.frames(_tree, 1)
		f += 1
	await Harness.frames(_tree, 4)
	return _ov() != null and _ov().showing


## Step 1 then 2: nothing on the ship while the text arrives; the choices a second after it is in;
## the part under the mouse hot; a click on the part resolves; FLY ON leaves the place's tag.
func _beat_and_click(_n: MapGen.MapNode) -> void:
	_d.open(0)
	await Harness.frames(_tree, 4)
	var ov := _ov()
	if not _ok("the event opened on the ship (an event tag, no band)", ov != null and ov.event_tag != null and _d.panel == null):
		return
	var c0 := _tag("Choice0")
	_ok("step 1: the event tag prints, nothing on the ship yet", _d.text != null and not _d.text.done and not ov.showing and c0 != null and not c0.visible)
	await Harness.frames(_tree, 30)
	_ok("  and still nothing while the text arrives", not ov.showing and not c0.visible)
	_d.text.skip()
	var f := 0
	while not ov.showing and f < 240:
		await Harness.frames(_tree, 1)
		f += 1
	_ok("step 2: the choices come %d frames after the text is in (a second is 60)" % f, f >= 57 and f <= 63)
	_ok("  and no SCAN SECTOR while they are up", _tag("ScanSector") == null)
	await Harness.frames(_tree, 20)
	var bad := _boxes(ov)
	for b in bad:
		print("  overlap: %s" % b)
	_ok("box test on %s: labels, event tag, HUD, goal line, hull and the one who talks never overlap (%d)" % [Run.hull.display_name(), bad.size()], bad.is_empty())
	var hit := ov.find_child("Choice0Part", false, false) as Control
	# (headless, the window never has the pointer, so nothing is "entered": the stills show it)
	hit.mouse_entered.emit()
	await Harness.frames(_tree, 2)
	_ok("the part under the mouse is hot, its label framed, the rest dim", ov.get("_hover") == 0 and c0.hot and not _tag("Choice1").hot)
	hit.mouse_exited.emit()
	_ok("the dim labels keep their price and odds", _tag("Choice0").cost != "" and _tag("Choice0").cost.contains("SENSORS"))
	var bow := _tag("Choice2")
	_ok("its own walk-away holds the bow, and NOT NOW is not shown (ruling A)", _tag("NotNow") == null and bow != null and bow.verb.begins_with("BOW: "))
	var stood := ov.event_tag.get_rect()
	await _click(hit)
	f = 0
	while _d.page != &"result" and f < 120:
		await Harness.frames(_tree, 1)
		f += 1
	_ok("a click on the part took choice 0 (%s)" % _d.out.get("odds", ""), _d.page == &"result" and _d.choice == 0 and _d.out.get("ok", false))
	_ok("step 3: the event tag turned to their answer", ov.event_tag != null and ov.event_tag.body.text == String((_d.out.get("res", {}) as Dictionary).get("text", "")))
	await Harness.frames(_tree, 3)
	var now := ov.event_tag.get_rect()
	var kept := now.position.distance_to(stood.position) < 1.0
	_ok("  in the same place as steps 1 and 2 (%s, then %s)" % [stood, now], kept)
	var rows: Array = ov.get("_rows")
	var credits := rows.any(func(r: Array) -> bool: return String(r[0]).ends_with("CREDITS"))
	_ok("the reward stack says the credits, with nothing to press on them", credits and _tag("Reward") == null)
	var go := _tag("ScanSector")
	_ok("after it, the bridge says SCAN SECTOR (no FLY ON)", go != null and go.verb == "BRIDGE: SCAN SECTOR" and _tag("Continue") == null)
	await _cutaway()
	_d.text.skip()
	await _click(go)
	var f2 := 0
	while not Router.current is SystemMapScreen and f2 < 240:
		await Harness.frames(_tree, 1)
		f2 += 1
	_ok("SCAN SECTOR: the event is done and LOCAL gives way to the sector map", Router.current is SystemMapScreen)
	await _back_to_local()
	var idle := _tag("ScanSector")
	_ok("LOCAL again, nothing up: SCAN SECTOR stays on the bridge", idle != null and idle.is_visible_in_tree() and _d.page == &"")
	var tag := _sc.find_child("LocalTag", false, false) as LocalTag
	var words := tag.get_child_count() if tag != null else 0
	_ok("and the place's tag shows only with something to do (%d words, \"%s\")" % [words, tag.line if tag != null else ""],
		tag != null and (tag.visible == (words > 0)))
	_ok("the shelf is not shown", not (_sc.get("_quiet_holder") as Control).visible)


func _not_now() -> void:
	# AN EVENT ABOUT TO OPEN ON ITS OWN (held for the arrival, `deferred`) is never offered as
	# OPEN IT first (Jon, Nov 15): the place's tag waits for the event tag
	var tag0 := _sc.find_child("LocalTag", false, false) as LocalTag
	_d.deferred = [_d.node.index, 1]
	LocalEventDrawer.last = [_d.node.index, 1]
	if tag0 != null:
		tag0.fill(_d.node)
		await Harness.frames(_tree, 2)
	_ok("an event about to open on its own: no OPEN IT on the place's tag",
		tag0 != null and tag0.find_child("OPENIT", false, false) == null)
	_d.deferred = []
	if tag0 != null:
		tag0.fill(_d.node)
		await Harness.frames(_tree, 2)
	_ok("  nor before it was put off", tag0 != null and tag0.find_child("OPENIT", false, false) == null)
	if not await _open_settled(1):
		_ok("%s opened" % _d.node.options[1], false)
		return
	var nn := _tag("NotNow")
	_ok("%s has no walk-away: NOT NOW is on the bow" % _d.node.options[1], nn != null and nn.verb.begins_with("BOW"))
	await _click(nn)
	await Harness.frames(_tree, 3)
	_ok("NOT NOW: the event is gone and nothing was taken", _d.page == &"" and _d.choice == -1)
	var tag := _sc.find_child("LocalTag", false, false) as LocalTag
	await Harness.frames(_tree, 2)
	var oi: ShipChoices.Tag = tag.find_child("OPENIT", false, false) as ShipChoices.Tag if tag != null else null
	_ok("the tag offers OPEN IT", oi != null and oi.is_visible_in_tree())
	if oi != null:
		await _click(oi)
		await Harness.frames(_tree, 3)
		_ok("OPEN IT opens it again on the ship", _d.page == &"event" and _d.opt == 1)
		# (its text was printed once already: whole now, and the choices with no beat)
		_ok("  its text whole at once, never printed again, the choices with no beat",
			_d.text != null and _d.text.done and _ov().showing)
		_d.not_now()
		await Harness.frames(_tree, 2)


## LOCAL again (after SCAN SECTOR took the map): the screen and its drawer fetched anew.
func _back_to_local() -> void:
	# (the map parked the ship at a place; the test's events stand anywhere, as before it)
	ParkedShips.spots.erase(Run.at)
	Router.show_local()
	await Harness.frames(_tree, 90)
	ParkedShips.spots.erase(Run.at)
	_sc = Router.current as SectorScreen
	_d = _sc.get("_events") if _sc != null else null


## THE CUTAWAY OVER LOCAL (a click on your ship): nothing of ours drawn through it, then back.
func _cutaway() -> void:
	var cut := _sc.open_cutaway()
	await Harness.frames(_tree, 4)
	if not _ok("the cutaway opens over a result", cut != null):
		return
	var left := _shown_over(cut)
	_ok("  and nothing of the event or the place's tag is drawn through it (%s)" % ", ".join(left), left.is_empty())
	cut.close_now()
	var f := 0
	while _sc.get("_cutaway") != null and f < 120:
		await Harness.frames(_tree, 1)
		f += 1
	await Harness.frames(_tree, 2)
	_ok("  and all of it back when it closes", _ov().is_visible_in_tree())


## The party's claim: a choice a partner already took says so, and the event tag goes.
func _too_late(n: MapGen.MapNode) -> void:
	if not await _open_settled(2):
		_ok("slipping orbit opened", false)
		return
	n.taken.append(MapGen.OPTION_SITE + 2)
	await _click(_ov().find_child("Choice0Part", false, false) as Control)
	await Harness.frames(_tree, 4)
	_ok("taken by a partner first: too late, and the event goes (%s)" % _d.out.get("why", ""), _d.out.get("why", "") == "too_late" and _d.page == &"")


## +1 PART opens the pile, the band's SECTOR LOOT, right there.
func _loot() -> void:
	if not await _open_settled(3):
		_ok("mine drift opened", false)
		return
	await _click(_ov().find_child("Choice0Part", false, false) as Control)
	var f := 0
	while _d.page != &"result" and f < 120:
		await Harness.frames(_tree, 1)
		f += 1
	var rw := _tag("Reward")
	var bad3 := _boxes(_ov())
	_ok("step 3 box test: the stack, SCAN SECTOR and the event tag apart (%s)" % ", ".join(bad3), bad3.is_empty())
	_ok("what landed on the pile is a bracketed count (%s)" % (rw.verb if rw != null else "none"), rw != null and rw.loot and rw.verb == "+1 ITEM")
	if rw == null:
		return
	_d.text.skip()
	await _click(rw)
	await Harness.frames(_tree, 3)
	var tv := Harness.first(_sc, func(x: Node) -> bool: return x is TransferView)
	_ok("clicking it opens SECTOR LOOT (TransferView)", tv != null)
	if tv != null:
		var left := _shown_over(tv as Control)
		_ok("  and nothing of the event is drawn while it is up (%s)" % ", ".join(left), left.is_empty())
		(tv as TransferView).close()
		var fc := 0
		while _d.get("_transfer") != null and fc < 120:
			await Harness.frames(_tree, 1)
			fc += 1
		await Harness.frames(_tree, 2)
		_ok("  DONE brings the event back, its answer whole (never printed twice)",
			_ov().is_visible_in_tree() and _d.page == &"result" and _d.text != null and _d.text.done)
	_d.continue_on()
	await Harness.frames(_tree, 2)


## What of the event and the place's tag is still on screen over `tv`, by name.
func _shown_over(tv: Control) -> Array[String]:
	var out: Array[String] = []
	if _ov() != null and _ov().is_visible_in_tree():
		out.append("ShipChoices")
	var tag := _sc.find_child("LocalTag", false, false) as LocalTag
	if tag != null and tag.is_visible_in_tree() and UiRect.of(tag).intersects(UiRect.of(tv)):
		out.append("LocalTag")
	return out


## The band's warning on the pointed-at label: taking one of a pair closes the other.
func _warns() -> void:
	if not await _open_settled(4):
		_ok("salvage rights opened", false)
		return
	var c0 := _tag("Choice0")
	(_ov().find_child("Choice0Part", false, false) as Control).mouse_entered.emit()
	await Harness.frames(_tree, 2)
	_ok("pointed at, the label says what it closes (%s)" % c0.note, c0.note.begins_with("WILL MAKE STILL UNDER WARRANTY"))
	var bad := _boxes(_ov())
	_ok("  and still fits (%s)" % ", ".join(bad), bad.is_empty())
	(_ov().find_child("Choice0Part", false, false) as Control).mouse_exited.emit()
	await Harness.frames(_tree, 2)
	_ok("  and says nothing at rest", c0.note == "")
	_d.call(&"_drop")
	await Harness.frames(_tree, 2)


## Every hull: the most crowded encounter's choices settled, then the box test.
func _hulls(n: MapGen.MapNode) -> void:
	var crowd := n.options.size() - 1
	var crowded: Array = []
	var tested := 0
	for fr: HullData in DB.hull_frames:
		Run.hull = DB.at_tier(fr, 0)
		Sig.ship_changed.emit()
		await Harness.frames(_tree, 4)
		var ti := Array(n.taken).find(MapGen.OPTION_SITE + crowd)
		if ti >= 0:
			n.taken.remove_at(ti)
		if not await _open_settled(crowd):
			_ok("%s: the crowded event opened" % fr.display_name(), false)
			continue
		tested += 1
		var bad := _boxes(_ov(), true)
		_d.call(&"_drop")
		await Harness.frames(_tree, 3)
		for b in _boxes(_ov(), true):
			bad.append("at rest: " + b)
		if not bad.is_empty():
			crowded.append("%s (%s): %s" % [fr.display_name(), fr.manufacturer, "; ".join(bad.slice(0, 3))])
	for c in crowded:
		print("  crowded: %s" % c)
	_ok("%s on all %d hulls: nothing overlaps (%d crowd)" % [n.options[crowd], tested, crowded.size()], crowded.is_empty() and tested == DB.hull_frames.size())
	Run.fit_chassis(&"korvan", HullData.Weight.MEDIUM, 0)
	Sig.ship_changed.emit()


## Every authored encounter on a small, a middle and a big hull: the box test, the crowded named.
func _sweep(n: MapGen.MapNode) -> void:
	Router.animate_in_harness = false
	var crowded := {}
	var opened := 0
	for fr: HullData in [DB.hull_for(&"korvan", HullData.Weight.LIGHT), DB.hull_for(&"korvan", HullData.Weight.MEDIUM), DB.hull_for(&"korvan", HullData.Weight.HEAVY)]:
		Run.hull = DB.at_tier(fr, 0)
		Sig.ship_changed.emit()
		await Harness.frames(_tree, 3)
		for o in OptionTable.all():
			if (o.get("choices", []) as Array).is_empty():
				continue
			n.options.assign([StringName(o.id)])
			n.taken.clear()
			n.left.clear()
			_d.open(0)
			var fs := 0
			while _ov() != null and not (_ov().showing and float(_ov().get("_on_ship")) >= 1.0) and fs < 120:
				await Harness.frames(_tree, 1)
				fs += 1
			if _ov() == null or not _ov().showing:
				continue
			opened += 1
			var bad := _boxes(_ov(), true)
			if not bad.is_empty():
				crowded["%s on %s" % [o.id, fr.display_name()]] = "; ".join(bad.slice(0, 3))
			_d.not_now()
			await Harness.frames(_tree, 1)
	for k in crowded:
		print("  crowded: %s: %s" % [k, crowded[k]])
	_ok("every encounter on a light, a medium and a heavy hull: %d opened, %d crowd" % [opened, crowded.size()],
		opened >= 400 and crowded.is_empty())
	Run.fit_chassis(&"korvan", HullData.Weight.MEDIUM, 0)
	Router.animate_in_harness = true


## NOTHING OF OURS ON A MOVING SHIP: a real first arrival (LOCAL's approach) and a GO from the map
## (the zoom down and the fly-in): no mark of ours shows until the ship has stopped, and none moves
## once it has shown.
func _arrivals(n: MapGen.MapNode) -> void:
	SkillCheck.forced = -1
	SectorScreen._approached_at = -1
	LocalEventDrawer.pending = []
	Router.show_local()
	await _watch("the first arrival", 900)
	ZoomLadder.force = 1
	n.options.assign([&"dropped_load"])
	n.taken.clear()
	n.results.clear()
	Router.show_system()
	await Harness.frames(_tree, 60)
	var map := Router.current as SystemMapScreen
	if _ok("the sector map is up for GO", map != null):
		map.go_event(0)
		await _watch("a GO", 4000)
	ZoomLadder.force = -1


## Frame by frame: our marks while the ship moves, and where they stand once they show.
func _watch(what: String, cap: int) -> void:
	var early := 0
	var moved := 0
	var off_px := 0.0
	var rides := 0
	var live_hits := 0
	var blacks := 0
	var shown_at := -1
	var at := {}
	var last := Rect2()
	var f := 0
	while f < cap:
		# (at the top of a frame: the brackets as last drawn against the ship as it stood then)
		await _tree.process_frame
		f += 1
		var sc := Router.current as SectorScreen
		if sc == null:
			continue
		var d: LocalEventDrawer = sc.get("_events")
		var ov: ShipChoices = d.get("_ship") if d != null else null
		var view: EncounterView = sc.get("_view")
		var sv := view.ship_view() if view != null else null
		if ov == null or sv == null:
			continue
		# NO FLASH (Jon, Nov 16): no full-screen black laid over LOCAL as its event opens
		for c in sc.get_children():
			if c is ColorRect and (c as ColorRect).color.a > 0.2 and (c as ColorRect).size.x >= sc.size.x * 0.9:
				blacks += 1
		var hull := UiRect.of(sv)
		var moving := sv.arriving() or not sc.settled_local() or bool(sc.get("_flyin")) or hull != last
		last = hull
		# THE RETICLE: every drawn bracket on its part where the ship is now, moving or not
		if ov.showing and ov.is_visible_in_tree():
			var now := ov._hull_now()
			for m: ShipChoices.Mark in ov.get("_marks"):
				if m.part == &"" or not m.drawn.has_area() or not now.has_area():
					continue
				off_px = maxf(off_px, m.drawn.position.distance_to(ov._part_rect(m.part, now).position))
				if moving:
					rides += 1
				if moving and m.hit != null and m.hit.is_visible_in_tree():
					live_hits += 1
		var seen := {}
		for c in ov.get_children():
			if c is ShipChoices.Tag and (c as Control).is_visible_in_tree() and (c as Control).modulate.a > 0.01 and not (c as ShipChoices.Tag).bare:
				seen[String(c.name)] = (c as Control).global_position
		if seen.is_empty():
			continue
		if moving:
			early += 1
		if shown_at < 0:
			shown_at = f
			at = seen
		for k in seen:
			if at.has(k) and (seen[k] as Vector2).distance_to(at[k]) > 0.5:
				moved += 1
		if f - shown_at > 40:
			break
	_ok("%s: nothing of ours on the ship while it moves (%d frames), shown at frame %d" % [what, early, shown_at], early == 0 and shown_at > 0)
	_ok("  and nothing moved once shown (%d)" % moved, moved == 0)
	_ok("  the brackets ride with the ship: %d bracket-frames while it moved, at most %.1f px off their parts" % [rides, off_px], off_px <= 1.0)
	_ok("  and none can be clicked while it moves (%d)" % live_hits, live_hits == 0)
	_ok("  and no black laid over the screen as the event opens (%d frames)" % blacks, blacks == 0)


## The part click and the band's card resolve the same (the same choice, band, text and bill).
func _same_as_the_card() -> void:
	var got: Array = []
	for lay: StringName in [&"ship", &"band"]:
		LocalEventDrawer.layout = lay
		Rng.forced = 7
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var n := _node()
		n.options.assign([&"dropped_load"])
		var holder := Control.new()
		holder.size = Vector2(960, 540)
		_tree.root.add_child(holder)
		var d := LocalEventDrawer.new()
		d.screen = holder
		d.node = n
		holder.add_child(d)
		d.open(0)
		await Harness.frames(_tree, 2)
		if d.text != null:
			d.text.skip()
		var r: Dictionary
		if lay == &"ship":
			var ov := d.get("_ship") as ShipChoices
			var f := 0
			while not ov.showing and f < 240:
				await Harness.frames(_tree, 1)
				f += 1
			(ov.find_child("Choice0", false, false) as ShipChoices.Tag).pressed.emit()
			while d.page != &"result" and f < 360:
				await Harness.frames(_tree, 1)
				f += 1
			r = d.out
		else:
			r = await d.choose(0)
		got.append([r.get("band", -1), String((r.get("res", {}) as Dictionary).get("text", "")),
			(r.get("bill", []) as Array).map(func(b: Dictionary) -> int: return int(b.n))])
		holder.queue_free()
	LocalEventDrawer.layout = &"ship"
	_ok("a part's label resolves as the band's card does: %s" % [got[0][2]], got.size() == 2 and got[0] == got[1] and String(got[0][1]) != "")


# --------------------------------------------------------------- the box test

## The air between two boxes (0 when they touch).
func _gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(dx, dy).length()


## Every pair of the labels, the event tag and the reward lines, and each against the hull, the HUD,
## the goal line, the screen's edge and whoever talks: the overlaps, named.
func _boxes(ov: ShipChoices, where := false) -> Array[String]:
	var bad: Array[String] = []
	var boxes := {}
	for c in ov.get_children():
		if c is ShipChoices.Tag and (c as Control).visible and not (c as ShipChoices.Tag).bare:
			boxes[String(c.name)] = (c as Control).get_rect()
	if ov.event_tag != null:
		boxes["EventTag"] = ov.event_tag.get_rect()
	# THE WORDS CENTRED ON THEIR INK (Jon, Nov 15): as many empty rows over the cap tops as under the
	# foot, inside the box's edge, within a pixel
	for c in ov.get_children():
		if c is ShipChoices.Tag and (c as Control).visible and not (c as ShipChoices.Tag).bare:
			var t := c as ShipChoices.Tag
			var n := 1 + (1 if t.cost != "" and not t.loot else 0) + (1 if t.note != "" and not t.loot else 0)
			var last_line := t.verb if n == 1 else (t.note if t.note != "" else t.cost)
			var b0 := t.baseline()
			var top := b0 + ShipChoices.ink_of(t.verb).x
			var foot := b0 + float(n - 1) * t.LINE + ShipChoices.ink_of(last_line).y
			var over := top - 1.0
			var under := (t.size.y - 1.0) - foot
			if absf(over - under) > 1.0:
				bad.append("%s off centre (%d rows over, %d under)" % [t.name, int(over), int(under)])
	var keys := boxes.keys()
	for a in keys.size():
		for b in range(a + 1, keys.size()):
			if (boxes[keys[a]] as Rect2).intersects(boxes[keys[b]]):
				bad.append("%s on %s%s" % [keys[a], keys[b], " (%s, %s)" % [boxes[keys[a]], boxes[keys[b]]] if where else ""])
	var inv := ov.get_global_transform().affine_inverse()
	var others := {"hull": ov.get("_hull"), "talker": ov.get("_pin")}
	var pin: Rect2 = ov.get("_pin")
	if ov.event_tag != null and pin.has_area():
		var gap := _gap(ov.event_tag.get_rect(), pin)
		if gap > 90.0:
			bad.append("EventTag %d px from the talker" % int(gap))
		if ov.event_tag.get_rect().end.y <= pin.position.y:
			bad.append("EventTag over the talker (under, else beside, never over)")
	if Router.hud != null:
		others["HUD"] = inv * UiRect.of(Router.hud)
		if Router.hud.goal != null and Router.hud.goal.is_visible_in_tree():
			others["goal"] = inv * UiRect.of(Router.hud.goal)
	var screen := Rect2(Vector2.ZERO, ov.size)
	for k in keys:
		var r: Rect2 = boxes[k]
		if not screen.encloses(r):
			bad.append("%s off the screen" % k)
		for o in others:
			var orr: Rect2 = others[o]
			if orr.has_area() and r.intersects(orr):
				bad.append("%s on the %s%s" % [k, o, " (%s, %s)" % [r, orr] if where else ""])
	return bad
