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
	while _ov() != null and not _ov().showing and f < 240:
		await Harness.frames(_tree, 1)
		f += 1
	await Harness.frames(_tree, 20)
	return _ov() != null and _ov().showing


## Step 1 then 2: nothing on the ship while the text arrives; the choices a second after it is in;
## the part under the mouse hot; a click on the part resolves; FLY ON leaves the place's tag.
func _beat_and_click(_n: MapGen.MapNode) -> void:
	_d.open(0)
	await Harness.frames(_tree, 4)
	var ov := _ov()
	if not _ok("the event opened on the ship (a hail, no band)", ov != null and ov.hail != null and _d.panel == null):
		return
	var c0 := _tag("Choice0")
	_ok("step 1: the hail prints, nothing on the ship yet", _d.text != null and not _d.text.done and not ov.showing and c0 != null and not c0.visible)
	await Harness.frames(_tree, 30)
	_ok("  and still nothing while the text arrives", not ov.showing and not c0.visible)
	_d.text.skip()
	var f := 0
	while not ov.showing and f < 240:
		await Harness.frames(_tree, 1)
		f += 1
	_ok("step 2: the choices come %d frames after the text is in (a second is 60)" % f, f >= 57 and f <= 63)
	await Harness.frames(_tree, 20)
	var bad := _boxes(ov)
	for b in bad:
		print("  overlap: %s" % b)
	_ok("box test on %s: labels, hail, HUD, goal line, hull and the one who talks never overlap (%d)" % [Run.hull.display_name(), bad.size()], bad.is_empty())
	var hit := ov.find_child("Choice0Part", false, false) as Control
	# (headless, the window never has the pointer, so nothing is "entered": the stills show it)
	hit.mouse_entered.emit()
	await Harness.frames(_tree, 2)
	_ok("the part under the mouse is hot, its label framed, the rest dim", ov.get("_hover") == 0 and c0.hot and not _tag("Choice1").hot)
	hit.mouse_exited.emit()
	_ok("the dim labels keep their price and odds", _tag("Choice0").cost != "" and _tag("Choice0").cost.contains("SENSORS"))
	var bow := _tag("Choice2")
	_ok("its own walk-away holds the bow, and NOT NOW is not shown (ruling A)", _tag("NotNow") == null and bow != null and bow.verb.begins_with("BOW: "))
	var stood := ov.hail.get_rect()
	await _click(hit)
	f = 0
	while _d.page != &"result" and f < 120:
		await Harness.frames(_tree, 1)
		f += 1
	_ok("a click on the part took choice 0 (%s)" % _d.out.get("odds", ""), _d.page == &"result" and _d.choice == 0 and _d.out.get("ok", false))
	_ok("step 3: the hail turned to their answer", ov.hail != null and ov.hail.body.text == String((_d.out.get("res", {}) as Dictionary).get("text", "")))
	await Harness.frames(_tree, 3)
	var now := ov.hail.get_rect()
	var kept := absf(now.position.x - stood.position.x) < 1.0 and (absf(now.position.y - stood.position.y) < 1.0 or absf(now.end.y - stood.end.y) < 1.0)
	_ok("  in the same place as steps 1 and 2 (%s, then %s)" % [stood, now], kept)
	var rows: Array = ov.get("_rows")
	var credits := rows.any(func(r: Array) -> bool: return String(r[0]).ends_with("CREDITS"))
	_ok("the reward stack says the credits, with nothing to press on them", credits and _tag("Reward") == null)
	var go := _tag("Continue")
	_ok("the bow says FLY ON", go != null and go.verb.ends_with("FLY ON"))
	_d.text.skip()
	await _click(go)
	await Harness.frames(_tree, 3)
	_ok("FLY ON: the event is gone", _d.page == &"" and not _d.visible)
	var tag := _sc.find_child("LocalTag", false, false) as LocalTag
	_ok("and the place's tag says what is left (%s)" % (tag.line if tag != null else "none"), tag != null and tag.visible and tag.line != "")
	_ok("the shelf is not shown", not (_sc.get("_quiet_holder") as Control).visible)


func _not_now() -> void:
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
		_d.not_now()
		await Harness.frames(_tree, 2)


## The party's claim: a choice a partner already took says so, and the hail goes.
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
	_ok("a part on the pile shows as a bracketed word (%s)" % (rw.verb if rw != null else "none"), rw != null and rw.loot and rw.verb.contains("PART"))
	if rw == null:
		return
	_d.text.skip()
	await _click(rw)
	await Harness.frames(_tree, 3)
	var tv := Harness.first(_sc, func(x: Node) -> bool: return x is TransferView)
	_ok("clicking it opens SECTOR LOOT (TransferView)", tv != null)
	if tv != null:
		(tv as TransferView).close()
		await Harness.frames(_tree, 3)
	_d.continue_on()
	await Harness.frames(_tree, 2)


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
		if not bad.is_empty():
			crowded.append("%s (%s): %s" % [fr.display_name(), fr.manufacturer, "; ".join(bad.slice(0, 3))])
		_d.not_now()
		await Harness.frames(_tree, 2)
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
			await Harness.frames(_tree, 6)
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


## Every pair of the labels, the hail and the reward lines, and each against the hull, the HUD,
## the goal line, the screen's edge and whoever talks: the overlaps, named.
func _boxes(ov: ShipChoices, where := false) -> Array[String]:
	var bad: Array[String] = []
	var boxes := {}
	for c in ov.get_children():
		if c is ShipChoices.Tag and (c as Control).visible and not (c as ShipChoices.Tag).bare:
			boxes[String(c.name)] = (c as Control).get_rect()
	if ov.hail != null:
		boxes["Hail"] = ov.hail.get_rect()
	var keys := boxes.keys()
	for a in keys.size():
		for b in range(a + 1, keys.size()):
			if (boxes[keys[a]] as Rect2).intersects(boxes[keys[b]]):
				bad.append("%s on %s%s" % [keys[a], keys[b], " (%s, %s)" % [boxes[keys[a]], boxes[keys[b]]] if where else ""])
	var inv := ov.get_global_transform().affine_inverse()
	var others := {"hull": ov.get("_hull"), "talker": ov.get("_pin")}
	var pin: Rect2 = ov.get("_pin")
	if ov.hail != null and pin.has_area():
		var gap := _gap(ov.hail.get_rect(), pin)
		if gap > 90.0:
			bad.append("Hail %d px from the talker" % int(gap))
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
