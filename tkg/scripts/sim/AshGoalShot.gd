extends Node

## Photographs A.S.H. beside the goal line in several modes. Needs a window: `-- sheet=AshGoalShot`.
## Why: docs/why/AshGoalShot.md#shot-modes

var _out := ""
var _tree: SceneTree
var _n := 0


func _ready() -> void:
	_run.call_deferred()


func _secs(s: float) -> void:
	var t0 := GameClock.now()
	while GameClock.now() - t0 < s:
		await _tree.process_frame


func _tl(img: Image) -> Image:
	var k := float(img.get_width()) / 960.0
	var tl := img.get_region(Rect2i(0, 0, int(480.0 * k), int(270.0 * k)))
	tl.resize(960, 540, Image.INTERPOLATE_NEAREST)
	return tl


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := _tree.root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	_tl(img).save_png("%s/%s_tl.png" % [_out, name])
	var g: GoalLine = Router.hud.goal if Router.hud != null else null
	print("[ashgoalshot] %s: her box %s, goal %s, step %s" % [name,
		Ash.portrait.rect() if Ash.portrait != null and Ash.portrait.visible else Rect2(),
		g.rect() if g != null else Rect2(), g.step_rect() if g != null else Rect2()])


## One film frame: the top left, 2x.
func _frame() -> void:
	await RenderingServer.frame_post_draw
	_tl(_tree.root.get_texture().get_image()).save_png("%s/frames/%05d.png" % [_out, _n])
	_n += 1


func _film_secs(s: float) -> void:
	var t0 := GameClock.now()
	while GameClock.now() - t0 < s:
		await _frame()


## A real click on the HUD's tab for LOCAL (`local`) or the sector map, as a
## hand makes it (`CalmLadderTest._click`), filmed.
func _tab(local: bool) -> void:
	var h := Router.hud
	var b: Button = h._tab_sector if local else h._tab_system
	var at := b.get_global_rect().get_center()
	var vp := GameShell.input_target(_tree)
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	vp.push_input(mm)
	b.notification(Control.NOTIFICATION_MOUSE_ENTER)
	for i in 3:
		await _frame()
	for down in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = down
		mb.position = at
		mb.global_position = at
		mb.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		vp.push_input(mb)
		await _frame()
		await _frame()
	b.notification(Control.NOTIFICATION_MOUSE_EXIT)


func _start(intro_heard: bool) -> void:
	Ash.forced = true
	Ash.reload()
	Ash.set_on(true)
	Hints.forced = true
	Hints.reset()
	Ash.reload()
	Rng.forced = Harness.seed_arg(4242)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	# (every new run has her introduction: `intro=0` takes it off, for a launch
	# line from the bag)
	if intro_heard:
		Ash.mark_intro(true)


func _run() -> void:
	_tree = get_tree()
	_out = Harness.arg("out", "user://ashgoalshot")
	DirAccess.make_dir_recursive_absolute(_out)
	await _tree.process_frame
	match Harness.arg("mode", "stills"):
		"fight":
			await _fight()
		"film":
			await _film()
		"stepfilm":
			await _stepfilm()
		"introfilm":
			await _introfilm()
		"settings":
			await _settings()
		"decks":
			await _decks()
		"cutaway":
			await _cutaway()
		_:
			await _stills()
	Ash.forced = false
	Hints.forced = false
	_tree.quit(0)


func _stills() -> void:
	await _start(Harness.arg("intro", "1") != "1")
	Router.show_local()
	# her lines as they come, each photographed once it holds
	var n0 := Ash.said_log.size()
	var shot := n0
	var t0 := GameClock.now()
	while GameClock.now() - t0 < 30.0 and shot < n0 + 3:
		await _tree.process_frame
		var p := Ash.portrait
		if Ash.said_log.size() > shot and p != null and p.phase == AshPortrait.Phase.HOLDING:
			var d: Dictionary = Ash.said_log[shot]
			print("[ashgoalshot] line %d: %s \"%s\"" % [shot - n0, d.kind, d.line])
			await _shot("local_%d_%s" % [shot - n0, d.kind])
			shot += 1
	for d: Dictionary in Ash.said_log.slice(n0):
		print("[ashgoalshot] said at %.2f: %s" % [d.at, d.kind])
	await _secs(1.0)
	await _shot("local_after")
	if Ash.portrait != null:
		Ash.portrait.cut()
	Router.show_starchart()
	await _secs(3.0)
	await _shot("chart")
	Router.show_system()
	await _secs(3.0)
	await _shot("map")


## Her line up and holding (a teaching line `lid`, or any bark), in `secs`.
func _holding(lid: StringName, secs: float) -> bool:
	var t0 := GameClock.now()
	while GameClock.now() - t0 < secs:
		await _tree.process_frame
		var p := Ash.portrait
		if p != null and p.phase == AshPortrait.Phase.HOLDING and (lid == &"" or Ash.lesson == lid):
			return true
	return false


func _fight() -> void:
	await _start(true)
	# a run already under way: the jump made, LOCAL's hints seen; the fight's not
	Run.jumps = 1
	for id in Hints.ORDER:
		if not id in [&"hand", &"intent", &"endturn", &"brace", &"heat"]:
			Hints.mark_seen(id)
	for id in Hints.STEPS:
		Hints.mark_seen(id)
	Router.show_local()
	await _secs(2.0)
	Router.start_combat(DB.enemies[&"cutter"], [], false, false)
	if await _holding(&"hand", 15.0):
		await _shot("fight_teach_first")
	Hints.spend()
	await _secs(1.5)
	# a card played: the enemy's intent is the next lesson
	var cb := Router.combat
	for i in cb.hand.size():
		if cb.can_play(cb.hand[i] as CardData):
			cb.play(i, 0)
			break
	if await _holding(&"", 15.0):
		await _shot("fight_teach_mid")
	Hints.spend()
	await _secs(1.0)
	for id in Hints.ORDER:
		Hints.mark_seen(id)
	await _secs(1.0)
	if Ash.portrait != null:
		Ash.portrait.cut()
	Ash._last_end = -INF
	Ash._fight_lines = 0
	Run.heat = Run.heat_cap() + 2
	Sig.resources_changed.emit()
	if await _holding(&"", 15.0):
		await _shot("fight_bark")


func _film() -> void:
	DirAccess.make_dir_recursive_absolute(_out + "/frames")
	await _start(true)
	# the step up as the reminder (said already), so the goal and the step move
	Hints.mark_seen(&"said_step_jump")
	for id in Hints.ORDER:
		Hints.mark_seen(id)
	Router.animate_in_harness = true
	# the calm move on, stepped a frame at a time (filmed at 30 a second)
	ZoomLadder.force = 1
	ZoomLadder.fixed_dt = 1.0 / 30.0
	Router.show_local()
	# (no launch line in this film: the goal and the step alone)
	Ash.waiting.clear()
	var t0 := GameClock.now()
	while GameClock.now() - t0 < 20.0 and not (Router.hud.goal.visible and Router.hud.goal.modulate.a > 0.99):
		await _tree.process_frame
	await _secs(1.0)
	await _film_secs(0.6)
	await _tab(false)
	for i in 600:
		await _frame()
		if not ZoomLadder.busy() and i > 10:
			break
	await _film_secs(0.8)
	await _tab(true)
	for i in 600:
		await _frame()
		if not ZoomLadder.busy() and i > 10:
			break
	await _film_secs(0.8)
	print("[ashgoalshot] film: %d frames" % _n)


func _stepfilm() -> void:
	DirAccess.make_dir_recursive_absolute(_out + "/frames")
	await _start(true)
	for id in Hints.ORDER:
		Hints.mark_seen(id)
	Router.animate_in_harness = true
	Router.show_local()
	# from the ship at rest: the step said, then its line coming back
	var t0 := GameClock.now()
	while GameClock.now() - t0 < 20.0 and not (Ash.lesson == &"step_jump" and Ash.lesson_up()):
		await _tree.process_frame
	await _film_secs(0.3)
	while Ash.lesson_up():
		await _frame()
	await _film_secs(1.6)
	print("[ashgoalshot] stepfilm: %d frames" % _n)


func _introfilm() -> void:
	await _start(false)
	Router.animate_in_harness = true
	Router.show_local()
	var t0 := GameClock.now()
	var said := {}
	while GameClock.now() - t0 < 40.0:
		await _tree.process_frame
		for d: Dictionary in Ash.said_log:
			if not said.has(d.kind):
				said[d.kind] = GameClock.now() - t0
				print("[ashgoalshot] introfilm: %s at %.2f s" % [d.kind, said[d.kind]])
		if said.has(&"tut_step_jump") and not Ash.lesson_up():
			break
	await _secs(1.5)


func _settings() -> void:
	await _start(true)
	Router.show_local()
	await _secs(2.0)
	var main: Node = Router.content
	while main != null and not main.has_method("_open_settings"):
		main = main.get_parent()
	if main == null:
		return
	main.call("_open_settings")
	await _secs(1.0)
	var panel: SettingsPanel = null
	for n in _tree.root.find_children("*", "SettingsPanel", true, false):
		panel = n as SettingsPanel
	if panel == null:
		return
	var lab: Control = null
	for n in panel.find_children("*", "Label", true, false):
		if (n as Label).text == "TUTORIAL":
			lab = n as Control
	if lab != null:
		# (the HINTS section at the top of the page, its rows all in sight)
		await _tree.process_frame
		var sc := panel._scroll
		sc.scroll_vertical = int(sc.scroll_vertical + lab.get_global_rect().position.y - sc.get_global_rect().position.y - 40.0)
	await _secs(0.5)
	await _shot("settings")


## THE DECKS' FIRST-VISIT HINTS, as drawn: each deck opened by its button with
## her on (her line holding, its outline), then again with her off (the card).
func _decks() -> void:
	await _start(true)
	Run.jumps = 1
	for id in Hints.ORDER:
		if not Hints.DECK_HINTS.has(id):
			Hints.mark_seen(id)
	for id in Hints.STEP_LINES:
		Hints.mark_seen(StringName("said_" + String(id)))
	# (`pick=low`: a station under a city instead, its board a board and its
	# lab a lower level's; every station has all five decks since Nov 3)
	var low := Harness.arg("pick", "") == "low"
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.STATION and not Contracts.board(m).is_empty() 				and (Fabricator.has_bench(m) if not low else int(m.development) < 3):
			Run.at = m.index
			m.visited = true
			print("[ashgoalshot] decks at %s (development %d)" % [MapGen.star_name(m), int(m.development)])
			break
	# (flown in: hull and fuel spent, so the yard's drones have work)
	Run.hp = maxi(1, Run.max_hp() - 12)
	Run.fuel = maxi(1, Run.fuel - 4)
	Router.docked = false
	Router.park_at_station()
	Router.show_station()
	await _secs(2.0)
	var st := Router.current as StationScreen
	if st == null:
		return
	for ash_on: bool in [true, false]:
		Ash.set_on(ash_on)
		for id in Hints.DECK_HINTS:
			Hints.mark_seen(id, false)
		for id: StringName in [&"shipyard", &"promenade", &"exchange", &"hiring_board", &"research"]:
			var tab: StringName = Hints.DECK_HINTS[id]
			if not st._tabs_on.get(tab, true):
				continue
			(st._tabs[tab] as Button).pressed.emit()
			var t0 := GameClock.now()
			var up := false
			while GameClock.now() - t0 < 25.0 and not up:
				await _tree.process_frame
				if ash_on:
					up = Ash.lesson == id and Ash.portrait != null and Ash.portrait.phase == AshPortrait.Phase.HOLDING
				else:
					up = Hints.card != null and is_instance_valid(Hints.card) and Hints.card.id == id
			if not up:
				print("[ashgoalshot] MISSING %s (%s)" % [id, "ash" if ash_on else "card"])
				continue
			await _secs(0.6)
			var name := "deck_%s%s_%s" % ["low_" if low else "", id, "ash" if ash_on else "card"]
			await RenderingServer.frame_post_draw
			_tree.root.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
			print("[ashgoalshot] %s: %s %s, outline %s, subject %s" % [name, "her box" if ash_on else "card",
				Ash.portrait.rect() if ash_on else Hints.card.card_rect(), Ash.outline_rect(),
				st.deck_subject(tab)])
			Hints.spend()
			await _secs(Hints.GAP_S + 0.4)
	Ash.set_on(true)


func _cutaway() -> void:
	await _start(true)
	Run.jumps = 1
	for id in Hints.ORDER:
		if id != &"cutaway":
			Hints.mark_seen(id)
	for id in Hints.STEP_LINES:
		Hints.mark_seen(StringName("said_" + String(id)))
	Router.show_local()
	await _secs(3.0)
	for rebound: bool in [false, true]:
		if rebound:
			Keys.set_key(&"hold_turn", 0, KEY_T)
			Keys.set_key(&"part_flip", 0, KEY_G)
		Hints.mark_seen(&"cutaway", false)
		var sc := Router.current as SectorScreen
		if sc == null:
			return
		# (the arrival over and the screen at rest)
		var t0 := GameClock.now()
		while not sc.cutaway_ready() and GameClock.now() - t0 < 20.0:
			await _tree.process_frame
		var cut := sc.open_cutaway()
		if cut == null:
			print("[ashgoalshot] the cutaway did not open")
			return
		if await _holding(&"cutaway", 15.0):
			await _secs(0.5)
			var name := "cutaway_rebound" if rebound else "cutaway"
			print("[ashgoalshot] %s: \"%s\" (said: \"%s\")" % [name, Ash.portrait.line.c_escape(), Ash.portrait.spoken])
			await _shot(name)
			var img := _tree.root.get_texture().get_image()
			var k := float(img.get_width()) / 960.0
			var r := Ash.portrait.rect().grow(6.0)
			img.get_region(Rect2i(Vector2i(r.position * k), Vector2i(r.size * k))).save_png("%s/%s_box.png" % [_out, name])
		else:
			print("[ashgoalshot] MISSING her cutaway line")
		Hints.spend()
		cut.close_now()
		await _secs(1.5)
	Keys.reset(&"hold_turn")
	Keys.reset(&"part_flip")
