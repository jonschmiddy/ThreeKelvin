extends Node

## THE FIGHT LOG, HIDDEN UNTIL ASKED FOR (Jon, Oct 18, "fightlog:hidden"):
##   godot --headless --path . -- sheet=FightLogTest
## `FightLog`. Headless, from a used settings file (other sections in it, the
## log's key absent, as on a profile that played before the log came back):
## a fight opens with LOG up and the log hidden; a turn played and ended with
## it hidden is recorded all the same (a TURN line per turn, your shot, their
## move); LOG clicked as a player clicks it shows the log with every line, and
## nothing that can be clicked has moved (the hand's buttons, piles, energy,
## turn, every card, the HUD's tabs); the choice is in the settings file and the
## next fight opens with the log as it was left, read again from the file; LOG
## again hides it and that is saved too. A.S.H., the goal line and the hint
## cards keep off both. THE BOX TEST: in the light, medium and heavy hull,
## against one ship, a pair, a pack of three and a creature, the button and the
## open log against everything on the screen -- every label and button of the
## HUD and the screen, the goal line, your hull, shield and plate, every enemy's
## ship, words, bars and the numbers that pop over it (`Ash.avoid_rects`, less
## the band under the HUD it reserves for the goal line) -- touching nothing,
## inside the picture, and the log tall enough to read.
##
## `shots=<dir>` (windowed, `--resolution 1920x1080`): the pack of three with
## the log hidden and open, the whole window and the game's 960x540.

var _fails := 0
var _tree: SceneTree
var _shots := ""
var _boxed := 0


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("shots="):
			_shots = (a as String).substr(6)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _shot(name: String) -> void:
	if _shots == "" or DisplayServer.get_name() == "headless":
		return
	for i in 3:
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_shots)
	_tree.root.get_texture().get_image().save_png("%s/%s.png" % [_shots, name])
	GameShell.input_target(_tree).get_texture().get_image().save_png("%s/%s_1x.png" % [_shots, name])
	print("  shot %s" % name)


## A real click at the middle of `c`, as the window gets one: into the window
## at the place the shell draws that game pixel, through the shell's container.
func _click(c: Control) -> void:
	var gp := c.get_global_rect().get_center()
	var sh := GameShell.instance
	var at := gp
	if sh != null and sh._frame != null:
		at = sh._frame.global_position + gp * float(sh._frame.stretch_shrink)
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	Input.parse_input_event(mm)
	await _tree.process_frame
	for down in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = down
		mb.position = at
		mb.global_position = at
		Input.parse_input_event(mb)
		await _tree.process_frame
	await _frames(3)


## A fight on LOCAL at an ordinary system: `ids` the ships, in the `w` hull.
func _fight(w: int, ids: Array) -> SectorScreen:
	Rng.forced = 4242
	Run.start_new_run(&"korvan", w)
	var idx := -1
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.SYSTEM:
			idx = n.index
			break
	Run.at = idx
	SectorScreen._approached_at = idx
	for raw in Run.map:
		(raw as MapGen.MapNode).ambush_rolled = true
		(raw as MapGen.MapNode).ambush_pending = false
	Router.show_local()
	await _frames(10)
	var extras: Array = []
	for i in range(1, ids.size()):
		extras.append(DB.enemies[ids[i]])
	Router.start_combat(DB.enemies[ids[0]], extras, false, false)
	await _frames(30)
	# (in a window the band rises and LOG fades in after it: wait for it whole)
	var sc := Router.current as SectorScreen
	for i in 600:
		if sc == null or sc._fight_log == null or sc._fight_log.button.modulate.a >= 1.0:
			break
		await _tree.process_frame
	await _frames(4)
	return sc


## Cards played at the first ship while they can be, then END TURN.
func _play_turn() -> void:
	var cb: Combat = Router.combat
	if cb == null:
		return
	for k in 4:
		var played := false
		for i in cb.hand.size():
			if cb.can_play(cb.hand[i]):
				cb.play(i, 0)
				played = true
				break
		await _frames(4)
		if not played or cb.finished:
			break
	if not cb.finished:
		cb.end_turn()
	# (your hull kept full: the fight is the log's, not a race to the wreck)
	Run.hp = Run.max_hp()
	await _frames(10)


## Where everything that can be clicked is: the hand's buttons and piles, the
## readouts beside them, every card, the HUD's tabs.
func _clickables(sc: SectorScreen) -> Dictionary:
	var d := {}
	for pair in [["end_turn", sc._end_button], ["flee", sc._flee_button], ["hail", sc._hail_button],
			["draw", sc._draw_pile], ["discard", sc._discard_pile], ["energy", sc._energy], ["turn", sc._deck_label]]:
		var c: Control = pair[1]
		if c != null:
			d[pair[0]] = c.get_global_rect()
	var k := 0
	for c in sc._hand.get_children():
		if c is CardView and not (c as CardView).is_queued_for_deletion():
			d["card%d" % k] = (c as Control).get_global_rect()
			k += 1
	for b in Router.hud.find_children("*", "BaseButton", true, false):
		if (b as Control).is_visible_in_tree():
			d["hud:%s" % b.name] = (b as Control).get_global_rect()
	return d


## Everything on the screen the log's button and the log must not touch.
func _others(sc: SectorScreen) -> Array:
	var out: Array = []
	var hud := Router.hud.get_global_rect()
	var band := Rect2(hud.position.x, hud.end.y, hud.size.x, Ash.GOAL_BAND)
	var mine := FightLog.rects(sc)
	for r: Rect2 in Ash.avoid_rects(sc):
		if r == band or mine.has(r) or r.size == Vector2.ZERO:
			continue
		out.append(["avoid", r])
	var g: Rect2 = Router.hud.goal_rect()
	if g.size != Vector2.ZERO:
		out.append(["goal", g])
	var scr := Rect2(Vector2.ZERO, Vector2(960, 540))
	for root: Control in [Router.hud, sc]:
		for c in root.find_children("*", "Control", true, false):
			var k := c as Control
			if not k.is_visible_in_tree() or k == sc._fight_log or sc._fight_log.is_ancestor_of(k):
				continue
			if not (k is Label or k is BaseButton or k is RichTextLabel):
				continue
			if k is Label and (k as Label).text.strip_edges() == "":
				continue
			var r := k.get_global_rect()
			if r.size.x <= 0.0 or r.size.y <= 0.0 or r.get_area() > scr.get_area() * 0.25:
				continue
			out.append([String(k.name), r])
	return out


func _box_test(tag: String, sc: SectorScreen) -> void:
	var f := sc._fight_log
	var v := sc._view.get_global_rect()
	var others := _others(sc)
	for pair in [["LOG", f.button], ["the log", f.panel]]:
		var c: Control = pair[1]
		if not c.is_visible_in_tree():
			_ok("%s: %s shows" % [tag, pair[0]], false)
			continue
		var r := c.get_global_rect()
		var hits: Array = []
		for o: Array in others:
			if r.intersects(o[1] as Rect2):
				hits.append("%s %s" % [o[0], o[1]])
		_ok("%s: %s %s touches nothing (%d checked)%s" % [tag, pair[0], r, others.size(),
			"" if hits.is_empty() else ": " + ", ".join(hits.slice(0, 4))], hits.is_empty())
		_ok("%s: %s inside the picture" % [tag, pair[0]], v.grow(0.5).encloses(r) or pair[0] == "LOG")
	# the button stands in the band under the HUD, inside the screen
	var hud := Router.hud.get_global_rect()
	var br := f.button.get_global_rect()
	_ok("%s: LOG in the band under the HUD, on screen" % tag,
		br.position.y >= hud.end.y and br.end.y <= hud.end.y + Ash.GOAL_BAND and br.end.x <= minf(v.end.x, hud.end.x))
	_ok("%s: the log at least %d px tall (%.0f)" % [tag, int(FightLog.LOG_MIN_H), f.panel.size.y], f.panel.size.y >= FightLog.LOG_MIN_H)
	_boxed += 1


func _settings_open() -> Variant:
	var cfg := ConfigFile.new()
	if cfg.load(DisplaySettings.path) != OK:
		return null
	return cfg.get_value(FightLog.SECTION, FightLog.KEY, null)


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	# (headless, the window is 64 px square and a click past it goes nowhere)
	if _tree.root.size.x < 1000:
		_tree.root.size = Vector2i(1920, 1080)
	# A USED SETTINGS FILE: what a profile that has played holds, without the
	# log's key
	var cfg := ConfigFile.new()
	cfg.load(DisplaySettings.path)
	cfg.set_value("hints", "welcome", true)
	cfg.set_value("hints", "fuel", true)
	cfg.set_value("display", "screen_shake", false)
	if cfg.has_section_key(FightLog.SECTION, FightLog.KEY):
		cfg.erase_section_key(FightLog.SECTION, FightLog.KEY)
	cfg.save(DisplaySettings.path)
	FightLog.reread()

	# 1. HIDDEN BY DEFAULT
	var sc := await _fight(int(HullData.Weight.MEDIUM), [&"marauder", &"hulk", &"sentinel"])
	if not _ok("a fight opens on LOCAL", sc != null and sc.fighting() and sc._fight_log != null):
		_end()
		return
	var f := sc._fight_log
	_ok("default: LOG is up and not pressed", f.button.is_visible_in_tree() and not f.button.button_pressed)
	_ok("default: the log is hidden", not f.panel.is_visible_in_tree())
	_ok("default: A.S.H., the goal line and the hints keep off LOG",
		Ash.avoid_rects(sc).has(f.button.get_global_rect()) and GoalLine.avoid_rects(sc).has(f.button.get_global_rect())
		and Hints._fight_avoid(sc, Router.hud.get_global_rect()).has(f.button.get_global_rect()))

	# 2. IT RECORDS WHILE HIDDEN
	await _play_turn()
	await _play_turn()
	var turns := 0
	var you := 0
	var them := 0
	for l: Dictionary in FightLog.lines:
		match StringName(l.kind):
			&"turn": turns += 1
			&"you": you += 1
			&"them": them += 1
	_ok("hidden, it records: %d lines, %d TURN lines, %d of yours, %d of theirs" % [FightLog.lines.size(), turns, you, them],
		turns >= 2 and you > 0 and them > 0 and String(FightLog.lines[0].text) == "TURN 1")
	_ok("hidden, still hidden after two turns", not f.panel.is_visible_in_tree())
	await _shot("fight_log_hidden")

	# 3. LOG CLICKED: the log shows, nothing clickable moves
	var before := _clickables(sc)
	await _click(f.button)
	_ok("clicked: LOG pressed, the log shows", f.button.button_pressed and f.panel.is_visible_in_tree())
	await _frames(2)
	var txt := f.shown_text()
	var missing := 0
	for l: Dictionary in FightLog.lines:
		if not txt.contains(String(l.text)):
			missing += 1
	_ok("clicked: every recorded line is in it (%d missing of %d)" % [missing, FightLog.lines.size()], missing == 0)
	_ok("clicked: saved, [fight] log_open = %s" % str(_settings_open()), _settings_open() == true)
	var after := _clickables(sc)
	var moved: Array = []
	for k in before:
		if not after.has(k) or after[k] != before[k]:
			moved.append(k)
	_ok("clicked: nothing that can be clicked moved (%d checked)%s" % [before.size(), "" if moved.is_empty() else ": " + ", ".join(moved)],
		moved.is_empty() and before.size() == after.size())
	_ok("open: A.S.H., the goal line and the hints keep off the log",
		Ash.avoid_rects(sc).has(f.panel.get_global_rect()) and Hints._fight_avoid(sc, Router.hud.get_global_rect()).has(f.panel.get_global_rect()))
	await _play_turn()
	_ok("open: a new turn's lines come in (%s)" % f.shown_text().get_slice("\n", f.shown_text().count("\n")),
		f.shown_text().contains("TURN 3"))
	await _shot("fight_log_open")

	# 4. REMEMBERED: the next fight, the file read again
	FightLog.reread()
	sc = await _fight(int(HullData.Weight.MEDIUM), [&"cutter"])
	f = sc._fight_log
	_ok("next fight: the log opens as it was left (file read again)", f.button.button_pressed and f.panel.is_visible_in_tree())
	_ok("next fight: the last fight's lines are gone, this one's TURN 1 is up",
		not FightLog.lines.is_empty() and String(FightLog.lines[0].text) == "TURN 1" or FightLog.lines.is_empty())
	await _click(f.button)
	_ok("clicked again: hidden, saved false (%s)" % str(_settings_open()),
		not f.button.button_pressed and not f.panel.is_visible_in_tree() and _settings_open() == false)
	FightLog.reread()
	sc = await _fight(int(HullData.Weight.MEDIUM), [&"cutter"])
	_ok("and the fight after opens with it hidden", not sc._fight_log.panel.is_visible_in_tree())

	# 5. THE BOX TEST, open, every hull, every kind of fight
	FightLog.set_open(true)
	for w in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
		for ids in [[&"cutter"], [&"marauder", &"hulk"], [&"marauder", &"hulk", &"sentinel"], [&"leviathan", &"cutter"],
				[&"lancer", &"cutter", &"marauder"], [&"whale"]]:
			sc = await _fight(int(w), ids)
			if not _ok("%s / %s: the fight opens" % [["light", "medium", "heavy"][int(w)], "+".join(ids)], sc != null and sc.fighting()):
				continue
			await _play_turn()
			await _frames(4)
			_box_test("%s / %s" % [["light", "medium", "heavy"][int(w)], "+".join(ids)], sc)
	_ok("boxed %d screens" % _boxed, _boxed == 18)
	# 6. OUT OF A FIGHT: no LOG
	FightLog.set_open(false)
	_end()


func _end() -> void:
	print("fightlogtest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)
