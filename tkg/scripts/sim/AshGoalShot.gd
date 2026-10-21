extends Node

## A.S.H. BESIDE THE GOAL LINE, as the game draws it:
##   godot --path . --windowed --resolution 1920x1080 -- sheet=AshGoalShot ash hints out=<dir> [mode=...]
##
## mode=stills (the default): a new run on LOCAL with her and the hints on
## (fresh hints; `intro=1`, the default, a profile that has not heard her
## introduction, `intro=0` one that has), each of her lines photographed as it
## holds (`local_<n>_<kind>.png`), then the chart (`chart.png`) and the sector
## map (`map.png`) with the goal and its step up.
## mode=fight: a fight's first turn with her teaching line (the hand's), the
## same fight later with another (after the first card), and her bark over the
## heat cap (`fight_teach_first`, `fight_teach_mid`, `fight_bark`).
## mode=film: LOCAL -> SECTOR -> LOCAL by the HUD's tabs, the goal and its step
## up, every frame's top left (`frames/00000.png`...): run with `--fixed-fps 30`.
## mode=stepfilm: on LOCAL she says the goal's step, and its line comes back
## once she is done, every frame's top left, `--fixed-fps 30`.
## mode=introfilm: a new run's first LOCAL as played, for `--write-movie`: her
## introduction, the beat, the goal's first step, its line coming back; it
## quits a second after. Run with `--write-movie <dir>/film.avi --fixed-fps 30`.
## mode=settings: Settings over the run, scrolled to HINTS (`settings.png`).
## mode=decks: a station with all five decks, each opened by its button the
## first time: her line on it, holding, with its outline (`deck_<id>_ash.png`),
## then the same with her off, the card (`deck_<id>_card.png`); prints her box
## or the card's and the outline's. `pick=low`: a station under a city, the
## decks it has (`deck_low_<id>_...`).
## Each still is the whole window and a 2x crop of its top left (`_tl.png`, the
## first 480x270 game pixels). Prints her box, the goal's and the step's. Needs
## a window.

var _args: PackedStringArray
var _out := ""
var _tree: SceneTree
var _n := 0


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _secs(s: float) -> void:
	var t0 := GameClock.now()
	while GameClock.now() - t0 < s:
		await _tree.process_frame


func _frames(n: int) -> void:
	for i in n:
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


func _press() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev


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
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	# (every new run has her introduction: `intro=0` takes it off, for a launch
	# line from the bag)
	if intro_heard:
		Ash.mark_intro(true)


func _run() -> void:
	_tree = get_tree()
	_out = _arg("out", "user://ashgoalshot")
	DirAccess.make_dir_recursive_absolute(_out)
	await _tree.process_frame
	match _arg("mode", "stills"):
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
		_:
			await _stills()
	Ash.forced = false
	Hints.forced = false
	_tree.quit(0)


func _stills() -> void:
	await _start(_arg("intro", "1") != "1")
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
	Hints.click(_press())
	await _secs(1.5)
	# a card played: the enemy's intent is the next lesson
	var cb := Router.combat
	for i in cb.hand.size():
		if cb.can_play(cb.hand[i] as CardData):
			cb.play(i, 0)
			break
	if await _holding(&"", 15.0):
		await _shot("fight_teach_mid")
	Hints.click(_press())
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
	# (`pick=low`: a station under a city instead, its board a board, no lab)
	var low := _arg("pick", "") == "low"
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
		for id: StringName in [&"shipyard", &"promenade", &"exchange", &"hiring_board", &"laboratory"]:
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
			Hints.click(_press())
			await _secs(Hints.GAP_S + 0.4)
	Ash.set_on(true)
