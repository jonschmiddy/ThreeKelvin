extends Harness

## The first-run hints (`Hints`), on the real screens, headless:
##   godot --headless --path . -- hinttest
##
## Each hint fires once at its trigger, as a `HintCard` in the game's picture,
## never over what it points at; NO CLICK DISMISSES IT (Jon, Oct 22: real clicks
## through the viewport on the card leave it up and unspent), and it is spent
## when the player does what it teaches (`HintActs`), or, for the ones that only
## tell you something (`Hints.INFO`), after its reading time; never again after;
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
##
## THE FIRST SET, NOT THE DEEP TUTORIAL'S: the lessons added Oct 22
## (`Hints.DEEP`) are parked (marked seen) after every reset here, so this holds
## the first set's triggers and order as they were; `-- sheet=AshTutorTest`
## walks every lesson, the deep ones too, through a first run. The intent's line
## now comes at the start of turn 2, and brace's and heat's end on END TURN.

const HintActs := preload("res://scripts/sim/HintActs.gd")

var _tree: SceneTree
var _rng := RandomNumberGenerator.new()


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame
	Hints.forced = true
	Hints.set_process(false)
	_rng.seed = 2210
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
	_park_deep()
	_ok("after a reset, the hints and the goal's steps are unseen, and one seen since stays seen",
		not Hints.seen(&"ship") and not Hints.seen(&"wreck") and not Hints.seen(&"step_jump")
		and Hints.seen(&"events"))
	# (the cutaway's three: A.S.H.'s two sentences and its keys, Jon's merge:A, Oct 20)
	_ok("every hint is two lines at grade 5.2 or under, the cutaway's three (tools/prose_grade.py checks the grade; here: the lines)",
		Hints.ORDER.all(func(id: StringName) -> bool: return Hints.lines(id).size() == _lines_for(id)))

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
	# (LOCAL opens the event at the place the ship is, as GO does, Jon Oct 21;
	# here, as after NOT NOW, it has been put off this visit, so the scene's own
	# hints are what is seen: the band's own hint has its own check below, and
	# AshTutorTest teaches them in the auto-opened order)
	_put_off(n)
	var sc := await _local()
	# parked at the event's own place, as GO leaves the ship (`here_now`): the
	# map wrote where it left the ship as it went. The wreck lies there too.
	SystemMapScreen._parked[n.index] = {at = LocalEventDrawer.body_of(n, oi)}
	var wreck := Run.new_wreck(n, DB.enemies[&"cutter"])
	wreck.items.append(CreditChit.of(40))
	Run.sector_jetsam(n).items.append(CreditChit.of(25))
	_put_off(n)
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
		await _put_away()
	await _expect(&"loot")
	await _expect(&"ship")
	await _none("with all three dismissed, nothing more shows on LOCAL")
	_put_off(n)
	sc = await _local()
	await _none("back on LOCAL again, none of them shows a second time")
	LocalEventDrawer.last = []

	# THE SHIP HINT WAITS FOR AN IDLE LOCAL: not while an event's band is on its
	# way up (GO landing), nor while it is up; then it shows and stays
	Hints.mark_seen(&"ship", false)
	_put_off(n)
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
	var band_card := Hints.card != null and Hints.card.id == &"drawer"
	sc._events.not_now()
	await _frames(20)
	Hints.poll(0.05)
	# NOT NOW is one of the band's two answers (the deep tutorial's line says so):
	# it spends the band's card, as a choice does
	_ok("the band's card was up, and NOT NOW spent it", band_card and Hints.seen(&"drawer"))
	Hints.mark_seen(&"drawer", false)
	Hints.poll(Hints.GAP_S + 0.1)
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
		_ok("hand: its second line says where the cards that help go", "own ship" in _line(&"hand", 1))
		await _never(&"intent", "turn 1: no intent (it is turn 2's, the deep tutorial's pacing)")
		# (the hand's action is the first card)
		await _expect(&"hand")
		await _never(&"intent", "turn 1, a card played: still no intent")
		# play out the hand: then END TURN
		await _none("a card left to play: END TURN's hint waits", [], true)
		while await _play_one(cb):
			pass
		# brace up but not yet held over an end of turn: nothing
		cb.brace = 60
		fs._refresh_player()
		await _never(&"brace", "brace up, the turn not ended: its hint waits")
		_ok("endturn: it says the hand size the game deals (%d)" % Run.hand_size(),
			("draw %d new cards" % Run.hand_size()) in _line(&"endturn", 1))
		# (END TURN's action is END TURN)
		await _expect(&"endturn")
		var settled: bool = await _settle(fs)
		_ok("the next turn comes up", settled)
		_ok("brace was held over the end of turn, and charged its heat (%d heat)" % Run.heat,
			cb.brace_held >= 1 and Run.heat >= 1)
		# TURN 2: the intent at its start (its action, END TURN here), then a turn
		# each for brace and heat (each at a turn's start, ended by END TURN)
		var turn_was := cb.turn
		await _expect(&"intent")
		_ok("intent: it showed at the start of turn 2 (turn %d)" % turn_was, turn_was == 2 and Hints.seen(&"intent"))
		await _settle(fs)
		_ok("heat: it reads the live cap (%d), not a number written down" % Run.heat_cap(),
			("Past %d" % Run.heat_cap()) in _line(&"heat", 0))
		await _expect(&"heat")
		await _settle(fs)
		cb.brace = 60
		fs._refresh_player()
		await _expect(&"brace")
		await _settle(fs)
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

	# THE FIRST STATION: what it does, and its decks (one with all five: work on
	# its board and a laboratory)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.jumps = 1
	var full := _full_station()
	_ok("a station with all five decks (%s)" % (MapGen.star_name(full) if full != null else "none"), full != null)
	# (flown in, as a first dock is: some hull and fuel spent, so the yard's
	# drones have work and come)
	var hp0 := Run.hp
	var fuel0 := Run.fuel
	Run.hp = maxi(1, Run.max_hp() - 12)
	Run.fuel = maxi(1, Run.fuel - 4)
	Router.docked = false
	Router.park_at_station()
	Router.show_station()
	await _frames(60)
	await _expect(&"dock")
	await _decks()
	Run.hp = hp0
	Run.fuel = fuel0
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

	# THE CHART'S DOCK THE SHIP CANNOT FLY TO (Jon, Oct 18: "hint:fix"): on a
	# heavy frame, which reaches past its dish, a visited dock can be in reach,
	# on the chart and out of sight. The card's dock line names the one the
	# ship can fly to, or says none is in reach -- never that one.
	await _fuel_unflyable()

	# NO CLICK ADVANCES IT: a hint clicked on and left alone stays, however long
	# (nothing else waiting here, so it gives way to nothing); its subject
	# leaving hides it unspent
	Hints.reset()
	_park_deep()
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
			if i % 20 == 0 and Hints.card != null:
				await _click_on(Hints.card.card_rect())
		_ok("a minute, clicked on: the same hint is still up, still unspent, and none came after it",
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
		var did := HintActs.act(&"ship")
		Hints.poll(0.05)
		_ok("only its action spends it (%s)" % did, Hints.seen(&"ship") and Hints.card == null)
		await _put_away()

	# REPLAY TUTORIAL
	Hints.mark_seen(&"ship")
	Hints.mark_seen(&"step_event")
	Hints.reset()
	_ok("REPLAY TUTORIAL clears every hint and the goal line's steps",
		(Hints.ORDER + Hints.STEPS).all(func(id: StringName) -> bool: return not Hints.seen(id)))
	_park_deep()
	sc = await _local()
	if sc != null:
		await _expect(&"ship")

	# TUTORIAL OFF (Settings' TUTORIAL, Jon, Oct 20): a card up goes at once,
	# unspent; nothing shows and the goal line has no step, GOAL alone; the
	# switch is kept in the settings file; ON again, the hints pick up where the
	# player is (what was seen stays seen)
	Hints.reset()
	_park_deep()
	Hints.mark_seen(&"events")
	sc = await _local()
	Hints.mark_seen(&"ship", false)
	var shown_any := false
	for i in 60:
		Hints.poll(0.1)
		await _tree.process_frame
		if Hints.card != null:
			shown_any = true
			break
	var was_id := Hints.card.id if Hints.card != null else &""
	if _ok("tutorial: a card is up to turn off under (%s)" % was_id, shown_any):
		Hints.set_tutorial(false)
		await _frames(2)
		_ok("tutorial OFF mid-card: it goes at once, unspent", Hints.card == null and not Hints.seen(was_id))
	else:
		Hints.set_tutorial(false)
	var gl: GoalLine = Router.hud.goal
	await _frames(3)
	var step_txt := gl._step.text if gl != null else "?"
	_ok("tutorial OFF: GOAL shows, with no step under it (step \"%s\")" % step_txt, gl != null and gl.visible
		and gl.step_rect() == Rect2() and step_txt == "")
	_ok("tutorial OFF: off even though a harness forces the hints", not Hints.enabled())
	await _none("tutorial OFF: no hint shows")
	var cfg := ConfigFile.new()
	_ok("tutorial OFF is kept in the settings file", cfg.load(DisplaySettings.path) == OK
		and not bool(cfg.get_value("hints", "tutorial", true)))
	Hints.reload()
	_ok("and read back so", not Hints.tutorial_on())
	Hints.set_tutorial(true)
	_ok("tutorial ON: on again, and what was seen stays seen", Hints.enabled() and Hints.seen(&"events"))
	if was_id != &"":
		await _expect(was_id)
		await _put_away()

	# nothing over the escape menu (but its own SAVE & EXIT lesson, parked here:
	# AshTutorTest holds that one)
	Hints.reset()
	_park_deep()
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


## The decks' first-visit hints, in the rail's order from the deck the station
## opens on (`Hints.DECK_HINTS`).
const DECKS: Array[StringName] = [&"shipyard", &"promenade", &"exchange", &"hiring_board", &"laboratory"]


## A station with all five decks (work on its board, a laboratory), the ship at
## it; null if the map has none.
func _full_station() -> MapGen.MapNode:
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.STATION and Fabricator.has_bench(m) and not Contracts.board(m).is_empty():
			Run.at = m.index
			m.visited = true
			return m
	return null


## THE DECKS' FIRST-VISIT HINTS (Jon, Oct 20, playing the alpha: "There is no
## tutorial tip for the promenade, exchange, shipyard, laboratory, or hiring
## board"), through the real station screen and its deck buttons, from the dock
## just spent: each deck's hint shows the first time it is open, on its main
## thing, clear of the decks, UNDOCK and everything on the deck; clicked on, it
## stays unspent; the deck used spends it (every other one), or it is left by
## the next deck's button (a card is read as it shows, so that spends it too:
## said once, Jon's Oct 20 ruling); again, none comes back. The dock's, with a
## deck picked under it, is spent by that (its action); off with TUTORIAL OFF,
## back with REPLAY TUTORIAL; off in a party.
func _decks() -> void:
	var st := Router.current as StationScreen
	if not _ok("decks: the station is up, its five decks on (%s)" % (st._tabs_on if st != null else {}),
			st != null and DECKS.all(func(id: StringName) -> bool: return st._tabs_on.get(Hints.DECK_HINTS[id], true))):
		return
	_ok("decks: none spent before the first visit", DECKS.all(func(id: StringName) -> bool: return not Hints.seen(id)))
	# (what the decks need to be used: credits, a part to sell, the lab's stuff)
	HintActs.stock_up()
	for i in DECKS.size():
		var id: StringName = DECKS[i]
		var ready: bool = await _visit(st, id)
		if not _ok("%s: its deck open and its main thing up (%s)" % [id, st.deck_subject(Hints.DECK_HINTS[id])], ready):
			continue
		var up: bool = await _step_until(id)
		var got := String(Hints.card.id) if Hints.card != null else "none"
		if not _ok("%s: its hint shows on the first visit (got %s)" % [id, got], up):
			continue
		var c: HintCard = Hints.card
		_ok("%s: the card's words (%s)" % [id, " / ".join(_card_words(c))], _card_words(c) == Hints.lines(id))
		var subj := st.deck_subject(Hints.DECK_HINTS[id])
		_ok("%s: it points at the deck's main thing (%s, the deck's %s)" % [id, c.subject, subj],
			c.subject.grow(6.0).encloses(subj) and subj.grow(6.0).encloses(c.subject))
		_deck_box(st, id, c.card_rect(), c.subject)
		var made: int = await _click_on(c.card_rect())
		Hints.poll(0.3)
		_ok("%s: clicked %d times: it stays, unspent" % [id, made], Hints.card == c and not Hints.seen(id))
		if i % 2 == 0:
			# USED: its action spends it, the deck still open
			var did := HintActs.act(id)
			Hints.poll(0.05)
			_ok("%s: the deck used (%s): spent, the card gone" % [id, did if did != "" else "NOTHING TO USE IT WITH"],
				did != "" and Hints.seen(id) and (Hints.card == null or Hints.card.id != id))
		else:
			# LEFT WITHOUT USING IT: the next deck's button (the last back to the yard)
			var next: StringName = DECKS[(i + 1) % DECKS.size()]
			(st._tabs[Hints.DECK_HINTS[next]] as Button).pressed.emit()
			for f in 6:
				Hints.poll(0.1)
				await _tree.process_frame
			_ok("%s: left by another deck's button, no click: the card goes, and it is spent (read as it showed)" % id,
				(Hints.card == null or Hints.card.id != id) and Hints.seen(id))
		Hints.poll(Hints.GAP_S + 0.1)
	for id in DECKS:
		await _visit(st, id)
		await _none("%s again: its hint does not come back" % id, [&"ship"])

	# THE DOCK'S UP AND A DECK PICKED UNDER IT: that is the dock's action, so it
	# is spent, and the Promenade's shows after it
	Hints.mark_seen(&"dock", false)
	Hints.mark_seen(&"promenade", false)
	await _visit(st, &"shipyard")
	Hints._quiet = 0.0
	if _ok("queue: the dock's hint is up", await _step_until(&"dock")):
		await _visit(st, &"promenade")
		for i in 3:
			Hints.poll(0.1)
			await _tree.process_frame
		_ok("queue: a deck picked is the dock's action: spent", Hints.seen(&"dock") and (Hints.card == null or Hints.card.id != &"dock"))
		Hints.poll(Hints.GAP_S + 0.1)
		_ok("queue: then the Promenade's shows", await _step_until(&"promenade"))
		HintActs.act(&"promenade")
		Hints.poll(0.05)
		Hints.poll(Hints.GAP_S + 0.1)

	# TUTORIAL OFF: none on any deck; REPLAY TUTORIAL (pressed while off) and ON
	# again: each comes back, once
	# (the other hints as they were, after: the rest of this file meets them)
	var was_seen := {}
	for id in Hints.ORDER + Hints.STEPS:
		was_seen[id] = Hints.seen(id)
	Hints.set_tutorial(false)
	Hints.reset()
	_park_deep()
	for id in Hints.ORDER:
		if not DECKS.has(id):
			Hints.mark_seen(id)
	for id in DECKS:
		await _visit(st, id)
		await _none("tutorial OFF: no hint on the %s" % id)
	Hints.set_tutorial(true)
	for id in DECKS:
		await _visit(st, id)
		var back: bool = await _step_until(id)
		_ok("REPLAY TUTORIAL, then ON: the %s's hint comes back" % id, back)
		await _visit(st, DECKS[(DECKS.find(id) + 1) % DECKS.size()])
		Hints.poll(Hints.GAP_S + 0.1)
	for id in was_seen:
		if not DECKS.has(id):
			Hints.mark_seen(id, bool(was_seen[id]))

	# OFF IN A PARTY (Jon, "coop:B"), forced or not
	for id in DECKS:
		Hints.mark_seen(id, false)
	var was_state = Net.state
	Net.state = Net.State.HOSTING
	for id in DECKS:
		await _visit(st, id)
		await _none("in a party: no hint on the %s" % id)
	Net.state = was_state
	for id in DECKS:
		Hints.mark_seen(id)
	await _visit(st, &"shipyard")


## Open the deck of hint `id` by its button on the rail, and wait (on the
## game's clocks, up to 20 s) for its main thing to be up: the drones flown in,
## the lamp lit, the lab's scan passed.
func _visit(st: StationScreen, id: StringName) -> bool:
	var tab: StringName = Hints.DECK_HINTS[id]
	(st._tabs[tab] as Button).pressed.emit()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000:
		await _tree.process_frame
		if st._tab == tab and st.deck_subject(tab).has_area():
			await _frames(2)
			return true
	return false


## THE BOX TEST for a deck's card (or her box, `r`): on screen and clear of the
## HUD, the goal line, the decks and UNDOCK, every button and word on the
## station, the deck's pieces (the yard's ships and drones, the shelf, the
## till, the hold, the counter, the notes, the fabricator's screen) but the one
## it points at, and what it points at. Gathered here, not from `Ash`.
func _deck_box(st: StationScreen, id: StringName, r: Rect2, subject: Rect2) -> void:
	var hits: Array[String] = []
	if not st.get_viewport_rect().encloses(r):
		hits.append("off the screen")
	for b: Array in deck_things(st, subject):
		if (b[1] as Rect2).has_area() and r.intersects(b[1]):
			hits.append("%s %s" % [b[0], b[1]])
	if subject.has_area() and r.intersects(subject):
		hits.append("what it points at %s" % subject)
	_ok("%s: box test at %s (%s)" % [id, r, "nothing under it" if hits.is_empty() else ", ".join(hits.slice(0, 4))],
		hits.is_empty())


## Everything on the station a card or her box must keep off, [what, global
## rect]: the HUD and the goal line, the rail (its decks, UNDOCK, the header),
## every button and word, and the decks' pieces. `subject` (the thing pointed
## at) is left to the caller.
static func deck_things(st: StationScreen, subject: Rect2) -> Array:
	var out: Array = []
	out.append(["the HUD", Router.hud.get_global_rect()])
	var g := Hints.goal_rect()
	if g.has_area():
		out.append(["the goal line", g])
	if st._rail != null and st._rail.is_visible_in_tree():
		out.append(["the rail", st._rail.get_global_rect()])
	for c in st.find_children("*", "Control", true, false):
		var k := c as Control
		if k == null or not k.is_visible_in_tree() or k.size.x <= 0.0 or k.size.y <= 0.0:
			continue
		var words := (k is Label and (k as Label).text.strip_edges() != "") \
			or (k is RichTextLabel and (k as RichTextLabel).get_parsed_text().strip_edges() != "")
		if k is BaseButton or words:
			out.append(["%s %s" % [k.get_class(), k.name], k.get_global_rect()])
	var pieces: Array = []
	if st._scene != null and is_instance_valid(st._scene) and st._scene.is_visible_in_tree():
		for v: ShipView in [st._mine_view, st._scene_ship]:
			if v != null and is_instance_valid(v) and v.is_visible_in_tree():
				pieces.append(["a yard ship", v.get_global_transform() * v.ship_rect()])
		if st._scene.drones != null:
			var dr := st._scene.drones.services_rect()
			if dr.has_area():
				pieces.append(["the drones", st._scene.get_global_transform() * dr])
	var sh: Control = st._shop.shelf_node if st._shop != null else null
	if sh != null and is_instance_valid(sh) and sh.is_visible_in_tree():
		pieces.append(["the shelf", sh.get_global_transform() * Rect2(Vector2.ZERO, sh.size)])
	for k: Control in [st._till, st._hold_grid, st._sell_desk, st._bench_clip]:
		if k != null and k.is_visible_in_tree():
			pieces.append(["the %s" % k.get_class(), k.get_global_rect()])
	if st._work != null and st._work.is_visible_in_tree():
		for c in st._work.get_children():
			if c is Control and (c as Control).is_visible_in_tree():
				pieces.append(["a note on the board", (c as Control).get_global_rect()])
	if st._board != null and st._board.is_visible_in_tree():
		for r: Rect2 in st._board.chrome_rects():
			out.append(["the board's app bar or ticker", st._board.get_global_transform() * r])
		# every job note whole, real or drawn, but the real ones it points at
		for r: Rect2 in st._board.job_rects():
			var jr := st._board.get_global_transform() * r
			if not subject.grow(8.0).encloses(jr):
				out.append(["a job note on the board", jr])
		if st._board.pop_rect.has_area():
			out.append(["a popup on the board", st._board.get_global_transform() * st._board.pop_rect])
	for p: Array in pieces:
		if not (subject.has_area() and (p[1] as Rect2).grow(1.0).encloses(subject) or subject.grow(8.0).encloses(p[1])):
			out.append(p)
	return out


## A card's words, as drawn.
func _card_words(c: HintCard) -> Array:
	var out: Array = []
	for l in c.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out


func _press() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev


## `id` shows, in the tree, clear of its subject and on screen; a click
## dismisses it and it is seen.
func _fuel_unflyable() -> void:
	var mfr := Run.hull.manufacturer
	var weight := Run.hull.weight
	var at0 := Run.at
	var fuel0 := Run.fuel
	Run.fit_chassis(&"korvan", HullData.Weight.HEAVY)
	for raw in Run.map:
		if (raw as MapGen.MapNode).type == MapGen.NodeType.STATION:
			(raw as MapGen.MapNode).visited = true
	var bad: MapGen.MapNode = null
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type != MapGen.NodeType.SYSTEM:
			continue
		Run.at = m.index
		Run.chart_from(m)
		Run.fuel = 15
		var pick: MapGen.MapNode = null
		for raw2 in Run.map:
			var s: MapGen.MapNode = raw2
			if s.type != MapGen.NodeType.STATION or not Run.charted(s) or not Run.reachable_from(m, s) 					or Run.fuel_cost_to(s) > Run.fuel:
				continue
			if pick == null or Run.fuel_cost_to(s) < Run.fuel_cost_to(pick):
				pick = s
		if pick != null and not pick.sensed:
			bad = pick
			break
	if _ok("fuel: a dock on the chart one jump off that the ship cannot fly to (%s)"
			% (MapGen.star_name(bad) if bad != null else "none found"), bad != null and not Run.can_jump_to(bad)):
		Hints.mark_seen(&"fuel", false)
		Hints._dock_key = Vector2i(-2, -2)
		Router.show_starchart()
		await _frames(40)
		var up: bool = await _step_until(&"fuel")
		var lines: Array = []
		if up:
			for l in Hints.card.find_children("*", "Label", true, false):
				lines.append((l as Label).text)
		var d := Run.nearest_dock()
		var want := "No dock in reach. Make short jumps and look for one."
		if not d.is_empty():
			want = "Nearest dock: %s, %d jump%s." % [MapGen.star_name(d.node), int(d.jumps),
				"" if int(d.jumps) == 1 else "s"]
		_ok("fuel: the card names the dock it can reach, not the chart's (%s)" % [lines],
			up and lines.size() == 2 and lines[1] == want and lines[1] != "Nearest dock: %s, 1 jump." % MapGen.star_name(bad)
			and (d.is_empty() or Run.can_jump_to(d.node) or int(d.jumps) >= 2))
		if up:
			await _dismiss(&"fuel")
	Run.fit_chassis(mfr, weight)
	Run.at = at0
	Run.chart_from(Run.node_at())
	Run.fuel = fuel0


func _expect(id: StringName) -> void:
	var up: bool = await _step_until(id)
	var got := String(Hints.card.id) if Hints.card != null else "none"
	if not _ok("%s: its hint shows (got %s)" % [id, got], up):
		return
	await _dismiss(id)


## What an action opened on LOCAL or the station put away: your ship, a window.
func _put_away() -> void:
	var sc := Router.current as SectorScreen
	if sc != null:
		if sc._cutaway != null and is_instance_valid(sc._cutaway):
			sc._cutaway.close_now()
		if sc._transfer != null:
			sc._close_transfer()
	var st := Router.current as StationScreen
	if st != null and st._cutaway != null and is_instance_valid(st._cutaway):
		st._cutaway.close_now()
	await _frames(10)


## REAL CLICKS on `r` (a card), as a hand makes them: through the viewport
## (`push_input`), at its middle and two seeded points in it. The card ignores
## the mouse, so a click lands on what is under it; one that would land on a
## button is not made (the card is kept clear of its subject, not of every
## button, and what a button does is not the card's business).
func _click_on(r: Rect2) -> int:
	var made := 0
	var pts: Array[Vector2] = [r.get_center()]
	for i in 2:
		pts.append(r.position + Vector2(_rng.randf() * r.size.x, _rng.randf() * r.size.y))
	for at in pts:
		var mm := InputEventMouseMotion.new()
		mm.position = at
		mm.global_position = at
		_tree.root.push_input(mm, true)
		await _tree.process_frame
		if _tree.root.gui_get_hovered_control() is BaseButton:
			continue
		for down: bool in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = down
			ev.position = at
			ev.global_position = at
			_tree.root.push_input(ev, true)
		made += 1
		await _tree.process_frame
	return made


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
		Hints.lines(id).size() == _lines_for(id) and c.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	Hints.poll(0.3)
	# NO CLICK SENDS IT AWAY (Jon, Oct 22): clicks on the card, where a player
	# clicks to put it away
	var made: int = await _click_on(c.card_rect())
	Hints.poll(0.3)
	# (an information card is spent as it shows, Oct 23: said once, ever)
	var info := Hints.INFO.has(id)
	_ok("%s: clicked %d times: it stays, %s" % [id, made, "spent as it showed (information)" if info else "unspent"],
		made > 0 and Hints.card == c and Hints.seen(id) == info)
	if info:
		# only tells you something: gone by itself after its reading time, spent
		var t := 0.6
		while Hints.card == c and t < 30.0:
			Hints.poll(0.1)
			t += 0.1
		_ok("%s: an information card: gone by itself after its reading time (%.1f s, wants %.1f), spent" % [id, t, Hints.info_s(id)],
			Hints.card == null and Hints.seen(id) and t >= Hints.info_s(id) - 0.15)
	else:
		var did := HintActs.act(id)
		for i in 4:
			Hints.poll(1.0 / 60.0)
			await _tree.process_frame
		_ok("%s: its action done (%s): spent, and the card goes" % [id, did if did != "" else "NOTHING TO DO IT WITH"],
			did != "" and Hints.seen(id) and (Hints.card == null or Hints.card.id != id))
		# (what its action opened -- a wreck's window, the pile's, your ship on
		# LOCAL -- put away again, as a player does, before the next card can
		# come; the dock's picked a deck: back to the yard, where the decks are
		# walked from)
		if id in [&"wreck", &"loot"] or (id == &"ship" and Router.current is SectorScreen):
			await _put_away()
		var st := Router.current as StationScreen
		if id == &"dock" and st != null and st._tab != &"services":
			(st._tabs[&"services"] as Button).pressed.emit()
			await _frames(2)
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
				Hints.spend()
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
## The event at the place the ship is put off for this visit, as after NOT NOW:
## LOCAL opens none of its own (`LocalEventDrawer.auto_open`).
func _put_off(n: MapGen.MapNode) -> void:
	LocalEventDrawer._auto[n.index] = LocalEventDrawer.visit_key(n)


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


## A hint's lines: two, but the cutaway's three (A.S.H.'s words on the card, and
## the turn and flip keys under them: Jon, merge:A, Oct 20).
## The deep tutorial's lessons, marked seen (see the header).
func _park_deep() -> void:
	for id in Hints.DEEP:
		Hints.mark_seen(id)


static func _lines_for(id: StringName) -> int:
	return 3 if id == &"cutaway" else 2
