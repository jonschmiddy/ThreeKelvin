extends Harness

## The first-run hints (`Hints`), on the real screens, headless:
##   godot --headless --path . -- hinttest
##
## Each hint fires once at its trigger, as a `HintCard` in the game's picture,
## never over what it points at, and never again once a click has dismissed it.
## SHOW HINTS AGAIN (`Hints.reset`) brings them back, and the intro too.
##
## THE USED STATE, NOT THE FRESH ONE: the run starts from a settings file that
## already has hints seen, has been reset once, and has one hint (GO) seen again
## since. The flags go to the harness settings file, never the player's. What is
## checked is the card in the tree, not only the flag, so this cannot pass while
## nothing draws. The clock is stepped by hand (`Hints.poll`).

var _tree: SceneTree


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame
	Hints.forced = true
	Hints.set_process(false)
	Hints.set_process_input(false)
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_ok("the flags go to the harness settings file (%s), not the player's" % Hints.store_path(),
		Hints.store_path() != DisplaySettings.PATH)
	# the used state
	Hints.mark_seen(&"ship")
	Hints.mark_seen(&"wreck")
	FirstRunIntro.mark_seen(true)
	Hints.reset()
	Hints.mark_seen(&"go")
	Hints.reload()
	_ok("after a reset, the hints and the intro are unseen, and one seen since stays seen",
		not Hints.seen(&"ship") and not Hints.seen(&"wreck") and not FirstRunIntro.seen() and Hints.seen(&"go"))

	# LOCAL, with a wreck that still holds something and a pile on the floor
	var n := _system()
	if not _ok("a system to stand in", n != null):
		return _end()
	var wreck := Run.new_wreck(n, DB.enemies[&"cutter"])
	wreck.items.append(CreditChit.of(40))
	Run.sector_jetsam(n).items.append(CreditChit.of(25))
	var sc := await _local()
	if not _ok("LOCAL is up", sc != null):
		return _end()
	# three at once on screen; they come one at a time, the wreck first
	await _expect(&"wreck")
	await _expect(&"loot")
	await _expect(&"ship")
	await _none("with all three dismissed, nothing more shows on LOCAL")
	sc = await _local()
	await _none("back on LOCAL again, none of them shows a second time")

	# inside your ship
	var cut := sc.open_cutaway()
	if _ok("the cutaway opens", cut != null):
		await _expect(&"cutaway")
		cut.close_now()
		await _frames(5)
		cut = sc.open_cutaway()
		await _none("opened a second time, the cutaway's hint does not come back")
		if cut != null:
			cut.close_now()
		await _frames(5)

	# the event band's choices
	var oi := _plant_event(n)
	if _ok("an event with choices to open", oi >= 0 and sc._events != null):
		sc._events.open(oi)
		await _frames(10)
		await _expect(&"drawer")
		sc._events.not_now()
		await _frames(10)
		sc._events.open(oi)
		await _frames(10)
		await _none("the band opened again: its hint does not come back")
		sc._events.not_now()
		await _frames(10)

	# a fight's hand
	Router.start_combat(DB.enemies[&"cutter"], [], false, false)
	await _frames(40)
	var fs := Router.current as SectorScreen
	if _ok("a fight is up", fs != null and fs.fighting()):
		await _expect(&"hand")
		await _none("the hand stays, and its hint does not come back")

	# GO on the sector map, which this file had seen before the run began
	# (a fresh run: the fight above is left unfinished)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	n = _system()
	var map := await _event_page(n)
	if _ok("the sector map shows an event's page with GO", map != null and Hints.probe(&"go").size() > 0):
		await _none("GO was seen before this run, so its hint does not show")
		Hints.mark_seen(&"go", false)
		await _expect(&"go")

	# NO CLICK, NO ADVANCE: a hint left alone stays, however long; its subject
	# leaving hides it unspent
	Hints.reset()
	sc = await _local()
	if sc != null:
		await _step_until(&"ship")
		var card_was: HintCard = Hints.card
		var n_log := Hints.shown_log.size()
		for i in 120:
			Hints.poll(0.5)
		_ok("a minute with no click: the same hint is still up, still unspent, and none came after it",
			card_was != null and Hints.card == card_was and is_instance_valid(card_was) and not Hints.seen(&"ship")
			and Hints.shown_log.size() == n_log)
		Router.show_system()
		await _frames(20)
		Hints.poll(0.5)
		_ok("its subject gone after a long while: it hides, unspent",
			Hints.card == null and not Hints.seen(&"ship"))
		sc = await _local()
		var again: bool = await _step_until(&"ship")
		_ok("back on LOCAL, the unspent hint shows again", again)
		Hints.poll(0.3)
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		Hints.click(ev)
		_ok("only the click spends it", Hints.seen(&"ship") and Hints.card == null)

	# SHOW HINTS AGAIN
	Hints.mark_seen(&"ship")
	FirstRunIntro.mark_seen(true)
	Hints.reset()
	_ok("SHOW HINTS AGAIN clears every hint and the intro",
		Hints.ORDER.all(func(id: StringName) -> bool: return not Hints.seen(id)) and not FirstRunIntro.seen())
	sc = await _local()
	if sc != null:
		await _expect(&"ship")

	# nothing over the escape menu
	Hints.reset()
	sc = await _local()
	var main: Node = Router.content
	while main != null and not main.has_method("toggle_menu"):
		main = main.get_parent()
	if _ok("the escape menu's owner is above the screens", main != null):
		main.toggle_menu()
		await _frames(5)
		await _none("the escape menu is up: no hint shows over it")
		main.toggle_menu(false)
		await _frames(5)

	# off under a harness that has not asked
	Hints.forced = false
	Hints.reset()
	sc = await _local()
	await _none("off under a harness that did not ask for hints")
	_end()


func _end() -> void:
	Hints.forced = false
	Hints.set_process(true)
	Hints.set_process_input(true)
	Hints.reset()
	print("")
	verdict("hinttest")
	_tree.quit(1 if _fails > 0 else 0)


func _frames(k: int) -> void:
	for i in k:
		await _tree.process_frame


func _local() -> SectorScreen:
	Router.show_local()
	await _frames(40)
	return Router.current as SectorScreen


## Step the hints' clock until `id` is on screen (or 6 s of it pass).
func _step_until(id: StringName) -> bool:
	for i in 60:
		Hints.poll(0.1)
		await _tree.process_frame
		if Hints.card != null and Hints.card.id == id:
			return true
	return false


## `id` shows, in the tree, clear of its subject and on screen; a click
## dismisses it and it is seen.
func _expect(id: StringName) -> void:
	var up: bool = await _step_until(id)
	var got := String(Hints.card.id) if Hints.card != null else "none"
	if not _ok("%s: its hint shows (got %s)" % [id, got], up):
		return
	var c: HintCard = Hints.card
	_ok("%s: the card is in the game's picture" % id, c.is_inside_tree() and c.is_visible_in_tree()
		and c.get_parent() == Router.content.get_viewport())
	var screen: Rect2 = c.get_viewport_rect()
	_ok("%s: on screen, clear of what it points at (%s by %s, %s)" % [id, c.card_rect(), c.subject, c.side],
		screen.encloses(c.card_rect()) and not c.card_rect().intersects(c.subject))
	_ok("%s: two short lines, and it ignores the mouse" % id,
		Hints.lines(id).size() == 2 and c.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	Hints.poll(0.3)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	var took: bool = Hints.click(ev)
	await _tree.process_frame
	_ok("%s: a click anywhere dismisses it, and it is seen" % id,
		took and Hints.card == null and Hints.seen(id))
	# past the quiet between two hints
	Hints.poll(Hints.GAP_S + 0.1)


## Nothing shows over a few seconds of the hints' clock.
func _none(what: String) -> void:
	var shown := ""
	for i in 30:
		Hints.poll(0.1)
		await _tree.process_frame
		if Hints.card != null:
			shown = String(Hints.card.id)
			break
	_ok("%s%s" % [what, "" if shown == "" else " (showed %s)" % shown], shown == "")


## The first ordinary system, with the ship at it.
func _system() -> MapGen.MapNode:
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.SYSTEM and not m.cleared:
			Run.at = m.index
			m.visited = true
			SectorScreen._approached_at = m.index
			OptionTable.ensure(m)
			return m
	return null


## An event with choices planted here; its option index.
func _plant_event(n: MapGen.MapNode) -> int:
	for o in OptionTable.all():
		if (o.get("choices", []) as Array).size() >= 2 and not (o.get("tags", []) as Array).has(&"fight"):
			n.options.append(StringName(o.id))
			return n.options.size() - 1
	return -1


## The sector map with an event's page open.
func _event_page(n: MapGen.MapNode) -> SystemMapScreen:
	if n.options.is_empty():
		_plant_event(n)
	Router.show_system()
	await _frames(40)
	var map := Router.current as SystemMapScreen
	if map == null:
		return null
	for bi in map.view.layout.bodies.size():
		for bc in map.view.layout.bodies[bi].beacons:
			if bc.opt >= 0:
				map.open_beacon(bi, bc)
				await _frames(10)
				return map
	return null
