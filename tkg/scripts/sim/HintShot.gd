extends Node

## THE FIRST-RUN HINTS AND THE GOAL LINE IN PLACE (`Hints`, `GoalLine`), one
## still each as the game draws it:
##   godot --path . --windowed --resolution 1920x1080 -- sheet=HintShot hints keepwindow out=<dir>
##
## `hints` turns them on under the harness (the seen flags go to the harness
## settings file, which this resets first). It walks the real screens:
##   - LOCAL as a new run hands it over: the goal line and its first step;
##   - the chart: its hint, and the step as it reads there;
##   - the sector map after a jump, with events: its hint, and the next step;
##   - LOCAL at an event's derelict, a loaded wreck and a pile: the band LOCAL
##     opens there (as GO does, Jon Oct 21) first, then NOT NOW, wreck, loot;
##   - the cutaway; the event band again, its text arrived and its choices up;
##   - a wreck's window (salvage);
##   - a fight: the hand, END TURN with nothing left to play, then turn 2's
##     intent, heat and brace (held over the turn);
##   - a station (dock), its decks the first time each is open, the shipyard's ship;
##     the chart with the tank short (fuel).
## Each still is the whole window (`<n>_<id>.png`, so 1080p at that resolution),
## taken `HINT_S` after the hint shows, then it is dismissed with a click as a
## player would. A hint that never shows is printed as `[hintshot] MISSING <id>`.
## The deep tutorial's lessons (Oct 22) come up on the way and are passed.
## Needs a window.

const HINT_S := 0.5

var _args: PackedStringArray
var _out := ""
var _k := 0


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


## (real seconds: a still is a frame the renderer has drawn, not a game clock)
func _secs(t: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(t * 1000.0):
		await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	_k += 1
	get_tree().root.get_texture().get_image().save_png("%s/%02d_%s.png" % [_out, _k, name])
	print("  hintshot: %02d_%s" % [_k, name])


## Wait for hint `id`, photograph it, click it away.
func _hint(id: StringName, wait: float = 8.0) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(wait * 1000.0):
		await RenderingServer.frame_post_draw
		if Hints.card != null and is_instance_valid(Hints.card) and Hints.card.id == id:
			await _secs(HINT_S)
			_shot("hint_" + String(id))
			var c: HintCard = Hints.card
			print("  hintshot: %s card %s, subject %s, side %s" % [id, c.card_rect(), c.subject, c.side])
			_click()
			await _secs(Hints.GAP_S + 0.2)
			return
		if Hints.card != null and is_instance_valid(Hints.card) and Hints.card.id != id:
			print("  hintshot: (passing %s on the way to %s)" % [Hints.card.id, id])
			await _secs(HINT_S)
			_click()
	print("  [hintshot] MISSING %s (showing: %s)" % [id, Hints.card.id if Hints.card != null else "none"])


func _click() -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	Hints.spend()
	# (spent without being done, so the screen stays as it was: each still
	# counts as a visit of its own, or the one-new-lesson-a-visit pacing would
	# hold the next back, `Hints._pace_ok`)
	Hints._front_last = &""


## The goal line as it stands, photographed with nothing else asked of the screen.
func _goal(name: String) -> void:
	await _secs(0.6)
	var g: GoalLine = Router.hud.goal
	print("  hintshot: goal %s: %s, step \"%s\", at %s" % [name, "up" if g.visible else "NOT UP", g._step.text, g.rect()])
	_shot("goal_" + name)


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


func _play_one(cb: Combat) -> bool:
	for i in cb.hand.size():
		if cb.can_play(cb.hand[i] as CardData):
			cb.play(i, 0)
			await _secs(0.4)
			return true
	return false


func _run() -> void:
	var tree := get_tree()
	_out = _arg("out", "user://hintshot")
	DirAccess.make_dir_recursive_absolute(_out)
	await tree.process_frame
	Hints.reset()
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	# LOCAL as a new run hands it over: the goal and its first step
	Router.show_local()
	await _secs(9.0)
	await _goal("local_launch")
	# the chart
	Router.show_starchart()
	await _secs(2.5)
	await _hint(&"chart")
	await _goal("chart")
	# the sector map after a first jump, with its events
	var n := _system()
	Run.jumps = 1
	Hints.mark_seen(&"step_jump")
	Router.show_system()
	await _secs(2.5)
	await _hint(&"events")
	await _goal("map_events")
	# LOCAL: an event's derelict, a wreck still holding something, a pile
	Router.show_local()
	await _secs(2.5)
	await _goal("local_event_step")
	var oi := n.options.size()
	n.options.append(&"first_on_the_wreck")
	LocalEventDrawer.last = [n.index, oi]
	SystemMapScreen._parked[n.index] = {at = LocalEventDrawer.body_of(n, oi)}
	var wreck := Run.new_wreck(n, DB.enemies[&"cutter"])
	wreck.items.append(CreditChit.of(40))
	Run.sector_jetsam(n).items.append(CreditChit.of(25))
	Router.show_local()
	await _secs(2.5)
	# (LOCAL at the event's own place opens it, as GO does: its band first, then
	# NOT NOW puts it down and the scene's own come; it used to wait on the band
	# and print MISSING for the wreck and the loot)
	var sc := Router.current as SectorScreen
	if sc != null and sc._events != null and sc._events.page == &"event":
		await _hint(&"drawer", 25.0)
		sc._events.not_now()
		await _secs(1.0)
	await _hint(&"wreck")
	await _hint(&"loot")
	sc = Router.current as SectorScreen
	if sc != null:
		sc.open_cutaway()
		await _hint(&"cutaway")
		if sc._cutaway != null:
			sc._cutaway.close_now()
		await _secs(0.5)
		# a wreck's window
		sc._open_jetsam(wreck)
		await _hint(&"salvage")
		sc._close_transfer()
		await _secs(0.5)
		LocalEventDrawer.last = []
		# the event band: the middle-length event, its text arriving first
		var all: Array = OptionTable.all().duplicate()
		all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("body", "")).length() < String(b.get("body", "")).length())
		n.options.append(StringName(all[all.size() / 2].id))
		# (said at the event's place above: shown again here for its look)
		Hints.mark_seen(&"drawer", false)
		sc._events.open(n.options.size() - 1)
		await _hint(&"drawer", 25.0)
		sc._events.not_now()
		await _secs(0.5)
	# a fight, as it teaches itself
	Run.heat = 0
	Router.start_combat(DB.enemies[&"cutter"], [], false, false)
	await _secs(2.0)
	var cb: Combat = Router.combat
	for e in cb.enemies:
		(e as Combat.EnemyState).max_hp = 999
		(e as Combat.EnemyState).hp = 999
	await _hint(&"hand", 12.0)
	await _play_one(cb)
	while await _play_one(cb):
		pass
	await _hint(&"endturn")
	await _goal("fight")
	cb.brace = 60
	var fs := Router.current as SectorScreen
	fs._refresh_player()
	fs._on_end_turn()
	# (turn 2: the intent at its start, then heat and brace, held over the turn)
	await _hint(&"intent", 15.0)
	await _hint(&"heat")
	await _hint(&"brace")
	# a station: its decks, then your ship at the yard
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.STATION:
			Run.at = m.index
			m.visited = true
			break
	Run.jumps = 1
	Hints.mark_seen(&"ship", false)
	# (flown in: hull and fuel spent, so the yard's drones have work)
	Run.hp = maxi(1, Run.max_hp() - 12)
	Run.fuel = maxi(1, Run.fuel - 4)
	Router.park_at_station()
	Router.show_station()
	await _secs(3.0)
	await _hint(&"dock", 10.0)
	# the decks, each the first time it is open (the yard's first: your ship's
	# follows it)
	await _hint(&"shipyard", 15.0)
	await _hint(&"ship", 10.0)
	var st := Router.current as StationScreen
	for id: StringName in [&"promenade", &"exchange", &"hiring_board", &"laboratory"]:
		var tab: StringName = Hints.DECK_HINTS[id]
		if st != null and st._tabs_on.get(tab, true):
			(st._tabs[tab] as Button).pressed.emit()
			await _hint(id, 15.0)
	# fuel: the chart with the tank short
	_system()
	Run.fuel = 3
	Router.show_starchart()
	await _secs(2.5)
	await _hint(&"fuel")
	Hints.reset()
	tree.quit()
