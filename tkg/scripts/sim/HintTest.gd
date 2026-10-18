extends Harness

## The first-run hints (`Hints`), on the real screens, headless:
##   godot --headless --path . -- hinttest
##
## Each hint fires once at its trigger, as a `HintCard` in the game's picture,
## never over what it points at, and never again once a click has dismissed it;
## the ones a moment decides (the intent after the first card, END TURN when
## nothing is playable, brace once held over an end of turn, heat once it rises,
## fuel at a third of the tank) are also shown NOT to fire before it. SHOW HINTS
## AGAIN (`Hints.reset`) brings them back, and the goal line's steps.
##
## THE USED STATE, NOT THE FRESH ONE: the run starts from a settings file that
## already has hints seen, has been reset once, and has one hint (the map's
## events) seen again since. The flags go to the harness settings file, never
## the player's. What is checked is the card in the tree, not only the flag, so
## this cannot pass while nothing draws. The clock is stepped by hand
## (`Hints.poll`).

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
	Hints.mark_seen(&"step_jump")
	Hints.reset()
	Hints.mark_seen(&"events")
	Hints.reload()
	_ok("after a reset, the hints and the goal's steps are unseen, and one seen since stays seen",
		not Hints.seen(&"ship") and not Hints.seen(&"wreck") and not Hints.seen(&"step_jump")
		and Hints.seen(&"events"))
	_ok("every hint is two lines at grade 5.2 or under (tools/prose_grade.py checks the grade; here: two lines each)",
		Hints.ORDER.all(func(id: StringName) -> bool: return Hints.lines(id).size() == 2))

	var n := _system()
	if not _ok("a system to stand in", n != null):
		return _end()
	# A NEW RUN'S FIRST LOCAL says one thing, the goal line's step: the ship's
	# hint waits for the first jump
	var first := await _local()
	_ok("a new run's first LOCAL is idle", first != null and Hints._local_idle(first))
	await _never(&"ship", "before the first jump, the ship's hint does not show")
	Run.jumps = 1

	# THE CHART: its list and its two bars, once
	Router.show_starchart()
	await _frames(40)
	await _expect(&"chart")
	Router.show_starchart()
	await _frames(40)
	await _none("the chart again: its hint does not come back")

	# THE SECTOR MAP'S EVENTS, which this file had seen before the run began
	var map := await _map_list(n)
	if _ok("the sector map lists an open event", map != null and Hints.probe(&"events").size() > 0):
		await _none("the map's events were seen before this run, so their hint does not show")
		Hints.mark_seen(&"events", false)
		await _expect(&"events")
		map = await _map_list(n)
		await _none("the map again: its hint does not come back")

	# LOCAL, WITH AN EVENT'S DERELICT DRAWN, A WRECK THAT STILL HOLDS SOMETHING
	# AND A PILE ON THE FLOOR. The wreck's hint points at the wreck a click
	# opens, never at the derelict, which is scenery (tutorial audit: it stood on
	# "First on the wreck"'s freighter).
	var oi := n.options.size()
	n.options.append(&"first_on_the_wreck")
	LocalEventDrawer.last = [n.index, oi]
	var sc := await _local()
	# parked at the event's own place, as GO leaves the ship (`here_now`): the
	# map wrote where it left the ship as it went. The wreck lies there too.
	SystemMapScreen._parked[n.index] = {at = LocalEventDrawer.body_of(n, oi)}
	var wreck := Run.new_wreck(n, DB.enemies[&"cutter"])
	wreck.items.append(CreditChit.of(40))
	Run.sector_jetsam(n).items.append(CreditChit.of(25))
	sc = await _local()
	if not _ok("LOCAL is up", sc != null):
		return _end()
	var subj := LocalSubject.of(sc._view)
	_ok("the event's derelict is drawn on LOCAL beside the wreck", subj != null and not subj.drawn_rects().is_empty())
	var up: bool = await _step_until(&"wreck")
	if _ok("wreck: its hint shows", up):
		var c: HintCard = Hints.card
		var real := false
		for i in 8:
			var sl := sc._view.slot(i)
			if sl != null and sl.opened.is_valid() and (sl.get_global_transform() * sl.ink_rect()).is_equal_approx(c.subject):
				real = true
		_ok("wreck: it points at a wreck a click opens (its hull's ink), %s" % c.subject, real)
		var off := true
		if subj != null:
			for r: Rect2 in subj.drawn_rects():
				if c.card_rect().intersects(r):
					off = false
		_ok("wreck: the card stands clear of the event's derelict (%s)" % c.card_rect(), off)
		await _dismiss(&"wreck")
	await _expect(&"loot")
	await _expect(&"ship")
	await _none("with all three dismissed, nothing more shows on LOCAL")
	sc = await _local()
	await _none("back on LOCAL again, none of them shows a second time")
	LocalEventDrawer.last = []

	# THE SHIP HINT WAITS FOR AN IDLE LOCAL: not while an event's band is on its
	# way up (GO landing), nor while it is up; then it shows and stays
	Hints.mark_seen(&"ship", false)
	sc = await _local()
	LocalEventDrawer.pending = [n.index, 0]
	_ok("an event waiting to come up on LOCAL: the ship's hint has no subject", Hints.probe(&"ship").is_empty())
	LocalEventDrawer.pending = []
	sc._events.deferred = [n.index, 0]
	_ok("an event deferred until the camera lands: no subject either", Hints.probe(&"ship").is_empty())
	sc._events.deferred = []
	var pe := _plant_event(n)
	sc._events.open(pe)
	await _frames(10)
	await _never(&"ship", "the event band is up: the ship's hint waits")
	sc._events.not_now()
	await _frames(20)
	await _expect(&"ship")

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
	if _ok("an event with choices to open", pe >= 0 and sc._events != null):
		sc._events.open(pe)
		await _frames(10)
		await _expect(&"drawer")
		sc._events.not_now()
		await _frames(10)
		sc._events.open(pe)
		await _frames(10)
		await _none("the band opened again: its hint does not come back")
		sc._events.not_now()
		await _frames(10)

	# A WRECK'S WINDOW: drag a part into the hold, or double-click it
	var loaded := Run.new_wreck(n, DB.enemies[&"cutter"])
	loaded.items.append(CreditChit.of(30))
	sc = await _local()
	await _none("LOCAL with a wreck, no window open: no salvage hint")
	sc._open_jetsam(loaded)
	await _frames(20)
	await _expect(&"salvage")
	sc._close_transfer()
	await _frames(10)
	sc._open_jetsam(loaded)
	await _frames(20)
	await _none("a wreck's window again: its hint does not come back")
	sc._close_transfer()
	await _frames(10)

	# A FIGHT, IN THE ORDER IT TEACHES ITSELF
	Run.heat = 0
	Router.start_combat(DB.enemies[&"cutter"], [], false, false)
	await _frames(40)
	var fs := Router.current as SectorScreen
	var cb: Combat = Router.combat
	if _ok("a fight is up", fs != null and fs.fighting() and cb != null):
		for e in cb.enemies:
			(e as Combat.EnemyState).max_hp = 999
			(e as Combat.EnemyState).hp = 999
		await _expect(&"hand")
		_ok("hand: its second line names the cost corner", "energy cost" in _line(&"hand", 1))
		await _none("cards in hand, none played: no intent, no END TURN, no brace, no heat yet")
		# the first card: then the intent
		await _play_one(cb)
		await _expect(&"intent")
		var ic: Array = Hints.shown_log.slice(-1)
		_ok("intent: it showed after the first card", ic == [&"intent"])
		# play out the hand: then END TURN
		await _none("a card left to play: END TURN's hint waits", [], true)
		while await _play_one(cb):
			pass
		await _expect(&"endturn")
		_ok("endturn: it says the hand size the game deals (%d)" % Run.hand_size(),
			("draw %d new cards" % Run.hand_size()) in _line(&"endturn", 1))
		# brace up but not yet held over an end of turn: nothing
		cb.brace = 60
		fs._refresh_player()
		await _none("brace up, the turn not ended: its hint waits")
		fs._on_end_turn()
		var settled: bool = await _settle(fs)
		_ok("the next turn comes up", settled)
		_ok("brace was held over the end of turn, and charged its heat (%d heat)" % Run.heat,
			cb.brace_held >= 1 and Run.heat >= 1)
		await _expect(&"brace")
		await _expect(&"heat")
		_ok("heat: it reads the live cap (%d), not a number written down" % Run.heat_cap(),
			("Past %d" % Run.heat_cap()) in _line(&"heat", 0))
		await _none("every fight hint spent: none comes back this turn")
	# a second fight: none of them again
	Router.start_combat(DB.enemies[&"cutter"], [], false, false)
	await _frames(40)
	fs = Router.current as SectorScreen
	cb = Router.combat
	if fs != null and cb != null:
		for e in cb.enemies:
			(e as Combat.EnemyState).max_hp = 999
			(e as Combat.EnemyState).hp = 999
		await _play_one(cb)
		while await _play_one(cb):
			pass
		cb.brace = 60
		fs._refresh_player()
		fs._on_end_turn()
		await _settle(fs)
		await _none("a second fight played out the same way: no fight hint shows again")

	# THE FIRST STATION: what it does, and its decks
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.jumps = 1
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.STATION:
			Run.at = m.index
			m.visited = true
			break
	Router.show_station()
	await _frames(60)
	await _expect(&"dock")
	Router.show_station()
	await _frames(60)
	await _none("docked again: the station's hint does not come back", [&"ship"])

	# FUEL: not while the tank is full; once a third of it is left (`-- sheet=FuelTest`
	# has the threshold and the dock it names)
	n = _system()
	Router.show_starchart()
	await _frames(40)
	await _none("a full tank: no fuel hint")
	var was_fuel := Run.fuel
	Run.fuel = 3
	await _expect(&"fuel")
	Router.show_starchart()
	await _frames(20)
	await _none("the tank still short: its hint does not come back")
	Run.fuel = was_fuel

	# NO CLICK, NO ADVANCE: a hint left alone stays, however long; its subject
	# leaving hides it unspent
	Hints.reset()
	for id in Hints.ORDER:
		if id != &"ship":
			Hints.mark_seen(id)
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
	Hints.mark_seen(&"step_event")
	Hints.reset()
	_ok("SHOW HINTS AGAIN clears every hint and the goal line's steps",
		(Hints.ORDER + Hints.STEPS).all(func(id: StringName) -> bool: return not Hints.seen(id)))
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

	# off in a party (Jon, Oct 17: "coop:B")
	Hints.forced = false
	var was_state = Net.state
	Net.state = Net.State.HOSTING
	_ok("off in a party: enabled() is false", not Hints.enabled())
	Net.state = was_state

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
	await _dismiss(id)


func _dismiss(id: StringName) -> void:
	var c: HintCard = Hints.card
	_ok("%s: the card is in the game's picture" % id, c.is_inside_tree() and c.is_visible_in_tree()
		and c.get_parent() == Router.content.get_viewport())
	var screen: Rect2 = c.get_viewport_rect()
	_ok("%s: on screen, clear of what it points at (%s by %s, %s)" % [id, c.card_rect(), c.subject, c.side],
		screen.encloses(c.card_rect()) and not c.card_rect().intersects(c.subject))
	var g := Hints.goal_rect()
	_ok("%s: clear of the goal line (%s)" % [id, g], g.size == Vector2.ZERO or not c.card_rect().intersects(g))
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


## Nothing shows over a few seconds of the hints' clock (bar the ones in
## `allowed`, dismissed as they come). `quiet`: and nothing at all even of those.
func _none(what: String, allowed: Array = [], _quiet: bool = false) -> void:
	var shown := ""
	for i in 30:
		Hints.poll(0.1)
		await _tree.process_frame
		if Hints.card != null:
			if Hints.card.id in allowed:
				Hints.poll(0.3)
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = true
				Hints.click(ev)
				Hints.poll(Hints.GAP_S + 0.1)
				continue
			shown = String(Hints.card.id)
			break
	_ok("%s%s" % [what, "" if shown == "" else " (showed %s)" % shown], shown == "")


## Line `k` of hint `id`, or "" if it has none.
func _line(id: StringName, k: int) -> String:
	var ls := Hints.lines(id)
	return String(ls[k]) if k < ls.size() else ""


## Hint `id` never shows over a few seconds of the hints' clock (any other may,
## and is left up, unclicked and unspent).
func _never(id: StringName, what: String) -> void:
	var shown := false
	for i in 30:
		Hints.poll(0.1)
		await _tree.process_frame
		if Hints.card != null and Hints.card.id == id:
			shown = true
	_ok(what, not shown)


## Play the first card the fight will take; false when none will.
func _play_one(cb: Combat) -> bool:
	for i in cb.hand.size():
		var c: CardData = cb.hand[i]
		if cb.can_play(c):
			cb.play(i, 0)
			await _frames(6)
			return true
	return false


## The hand back up after END TURN.
func _settle(sc: SectorScreen) -> bool:
	for i in 600:
		await _tree.process_frame
		if not sc._hold and not sc._opening and sc._end_button != null \
				and sc._end_button.is_visible_in_tree() and not sc._end_button.disabled:
			await _frames(4)
			return true
	return false


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


## The sector map on its list of events.
func _map_list(n: MapGen.MapNode) -> SystemMapScreen:
	if n.options.is_empty():
		_plant_event(n)
	Router.show_system()
	await _frames(40)
	return Router.current as SystemMapScreen
