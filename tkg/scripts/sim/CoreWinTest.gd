extends Node

## THE CORE'S BOSS, BEATEN, THROUGH THE REAL DOORS:
##   godot --headless --path . -- sheet=CoreWinTest
##
## Jon, Oct 12: "when defeating the final boss at the core, let's have the body
## of the boss lootable, but let it end the alpha with a winning game popup.
## same music as the death screen."
##
## A run with things in its hold flies to the core, presses ENGAGE
## (`Router.engage_here`), and plays the custodian to a kill: its hull is cut to
## one and its block to none first, so the fight is short, and the cards are
## played through `Combat.play` as the hand plays them. Then, from the screen
## the router leaves:
##   - the custodian's body lying on LOCAL, NOT opened by itself (Jon: "I would
##     want to have to click the dead custodian"): SALVAGE THE CUSTODIAN said,
##     every door shut; clicking it (the wreck's own click) opens the popup with
##     the boss's own loot in it, and the win screen is NOT up yet;
##   - the run already in the record as a win, and the one save a won run may
##     have written: the core with the body on it (`core_won`). Quit there and
##     CONTINUE comes back to the body, still to click, recorded once;
##   - Tab doing nothing while the body is open, a part taken into the hold;
##   - DONE bringing up the win screen: YOU WON, Jon's note whole and unscrolled
##     at the game's size, the stats, TITLE, and the death screen's music
##     (`Audio.music_asked` &"gameover", which plays `Audio.DEATH_CUE`);
##   - a second kill closed with Escape, and a third left by a door that should
##     not be there (`Router.show_system`), both ending on the win screen;
##   - an ordinary fight won, which leaves you on LOCAL by its wreck with no
##     win screen, no loot step and no win in the record;
##   - and the death screen asking for the same music the win does.

var _tree: SceneTree
var _fails := 0


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _run() -> void:
	_tree = get_tree()
	await _frames(2)

	# ---------------------------------------------------------- one: DONE
	var core := await _to_core(31337)
	if not _ok("the run has a core", core >= 0):
		return _finish()
	var records_before := RunHistory.load_all().size()
	if not await _beat_core():
		return _finish()
	var sc := Router.current as SectorScreen
	_ok("the router leaves you on LOCAL", sc != null)
	_ok("with the loot step on (Router.final_loot)", Router.final_loot)
	_ok("the body's popup does NOT open by itself", sc != null and not sc.has_open_container())
	_ok("LOCAL says SALVAGE THE CUSTODIAN", sc != null and _find(sc, func(n: Node) -> bool:
		return n is Button and (n as Button).text == "SALVAGE THE CUSTODIAN") != null)
	# QUIT HERE, AND COME BACK: the body, still to click
	_ok("a save is left on disk: the core with its body", FileAccess.file_exists(SaveGame.path))
	var records_mid := RunHistory.load_all().size()
	Router.final_loot = false
	Router.show_launcher()
	await _frames(3)
	Router.continue_run()
	await _frames(4)
	sc = Router.current as SectorScreen
	_ok("CONTINUE comes back to the core's LOCAL, the body waiting",
		sc != null and Router.final_loot and Run.won and Router.core_body_here() != null
		and not sc.has_open_container())
	_ok("and nothing more is recorded", RunHistory.load_all().size() == records_mid)
	# the body clicked, as its wreck is clicked
	var slot := _body_slot(sc)
	if _ok("the body is a wreck on LOCAL you can click", slot != null and slot.opened.is_valid()):
		slot.opened.call()
		await _frames(3)
	_ok("clicking the body opens its popup", sc != null and sc.has_open_container())
	_ok("the win screen is NOT up yet", _win_screen() == null)
	_ok("the HUD is hidden while the body is open",
		Router.hud == null or not Router.hud.visible)
	var tv: TransferView = sc._transfer if sc != null else null
	var body: MapGen.Jetsam = tv._jetsam if tv != null else null
	_ok("the popup is the custodian's body",
		body != null and body.art == &"custodian" and body == Router.core_body_here())
	_check_loot(body)
	# EVERY PART CAN BE SEEN. The popup sized the far grid by the number of
	# things in it, so the body's big parts pushed the rest below a view with
	# no scrollbar (seen in the first still).
	if tv != null and tv._loose_scroll != null:
		var rows := tv._loose.content_rows()
		var shown := int(tv._loose_scroll.custom_minimum_size.y / HoldGrid.CELL)
		_ok("every part in the body is in view or a scroll away (%d rows, %d shown)" % [rows, shown],
			rows <= shown or tv._loose_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO)
	_ok("the run is won", Run.won and not Run.dead)
	var all := RunHistory.load_all()
	_ok("and recorded as a win, once",
		all.size() == records_before + 1
		and int((all.back() as Dictionary).get("outcome", -1)) == RunHistory.Outcome.WON)
	_ok("the save is still the core's (gone at DONE)", FileAccess.file_exists(SaveGame.path))
	_ok("the music is not the death cue yet", Audio.music_asked != &"gameover")

	# Tab is the one key that changes screens; it must not leave the body.
	await _press(KEY_TAB)
	await _frames(3)
	_ok("Tab leaves the body open", Router.current == sc and sc.has_open_container()
		and Router.final_loot and _win_screen() == null)

	# A part out of the body and into the hold, as a drag does it.
	var cargo_before := Run.cargo.size() + Run.pad.size()
	var took := false
	if body != null:
		for i in body.items.size():
			if await Run.take_from_jetsam(Run.node_at(), body, i):
				took = true
				break
	_ok("a part comes out of the body into the hold",
		took and Run.cargo.size() + Run.pad.size() == cargo_before + 1)
	await _frames(2)
	_ok("and the popup is still open after it", sc.has_open_container() and _win_screen() == null)

	var done := _button(tv, "DONE")
	if not _ok("the popup has DONE", done != null):
		return _finish()
	done.pressed.emit()
	await _frames(4)
	_check_win_screen("after DONE")
	_ok("and the save is gone", not FileAccess.file_exists(SaveGame.path))
	_ok("the run is recorded once, not twice", RunHistory.load_all().size() == records_before + 1)
	# Escape on the win screen is the escape menu, and its ABANDON used to
	# write an ABANDONED record after the WON.
	await _press(KEY_ESCAPE)
	await _frames(3)
	var pm := _pause_menu() as PauseMenu
	if _ok("Escape on the win screen opens the escape menu", pm != null):
		pm.quit_requested.emit()
		await _frames(4)
		var after := RunHistory.load_all()
		_ok("and leaving by ABANDON adds nothing to the record",
			after.size() == records_before + 1
			and int((after.back() as Dictionary).get("outcome", -1)) == RunHistory.Outcome.WON)
		_ok("and lands on the title", Router.current is LauncherScreen)

	# --------------------------------------------------------- two: Escape
	core = await _to_core(40404)
	if await _beat_core():
		_ok("(second kill) the body waits", Router.final_loot and _win_screen() == null)
		await _press(KEY_ESCAPE)
		await _frames(4)
		_check_win_screen("after Escape")
		_ok("and no escape menu came up instead", _pause_menu() == null)

	# -------------------------------------------- three: a door left open
	core = await _to_core(5150)
	if await _beat_core():
		_ok("(third kill) the body waits", Router.final_loot)
		Router.show_system()
		await _frames(6)
		_check_win_screen("after leaving by another door")

	# ------------------------------------------------ an ordinary fight
	await _ordinary_fight()

	# ----------------------------------------------- the death screen's cue
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	await _frames(2)
	Audio.music_asked = &""
	Run.die("Hull integrity lost.")
	Router.show_game_over()
	await _frames(2)
	_ok("the death screen asks for &\"gameover\" too", Audio.music_asked == &"gameover")
	var go := Router.current as GameOverScreen
	# A TITLE button since Oct 22 (the audit: RUN ENDED's only way back was Esc,
	# then ABANDON); still no note
	_ok("and has no note, and a TITLE button", go != null
		and go.card == null and _find(go, func(n: Node) -> bool: return n is NoteCard) == null
		and _button(go, "TITLE") != null)
	_ok("the cue both screens ask for is Lights Out, played once",
		Audio.DEATH_CUE == &"lightsout" and Audio.DEATH_CUE in Audio.ONE_SHOT)
	_finish()


## The wreck slot on LOCAL that is the custodian's body.
func _body_slot(sc: SectorScreen) -> EnemySlot:
	if sc == null:
		return null
	return _find(sc, func(n: Node) -> bool:
		return n is EnemySlot and (n as EnemySlot)._dead and (n as EnemySlot).opened.is_valid()) as EnemySlot


## A fresh run with a used hold, parked at the core on LOCAL.
func _to_core(s: int) -> int:
	Rng.forced = s
	print("  [seed] %d" % s)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	# NOT AN EMPTY SHIP: parts in the hold, a few jumps and kills behind it.
	for i in 2:
		Run.stow(LootGen.roll_module(6))
	Run.jumps = 41
	Run.kills = 17
	var idx := -1
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.CORE:
			idx = n.index
	if idx < 0:
		return -1
	Run.at = idx
	Run.map[idx].visited = true
	SectorScreen._approached_at = idx
	SaveGame.save()
	Router.show_local()
	await _frames(3)
	return idx


## ENGAGE, then the custodian played to a kill. True when the fight ended in
## the run's win.
func _beat_core() -> bool:
	Router.engage_here()
	for i in 30:
		if Router.combat != null and not Router.combat.enemies.is_empty():
			break
		await _frames(1)
	var cb: Combat = Router.combat
	if not _ok("ENGAGE at the core opens a fight", cb != null and not cb.enemies.is_empty()):
		return false
	var t: EnemyTemplate = cb.enemies[0].template
	_ok("against the custodian, a boss", t.id == &"custodian" and t.boss)
	_ok("which asks for the boss cue", Audio.music_asked == &"boss")
	Run.hp = Run.max_hp()
	var tries := 0
	while not cb.finished and tries < 30:
		tries += 1
		for e in cb.enemies:
			e.hp = mini(e.hp, 1)
			e.block = 0
		var played := false
		for i in cb.hand.size():
			if cb.can_play(cb.hand[i]):
				cb.play(i, 0)
				played = true
				break
		if not played and not cb.finished:
			cb.end_turn()
		await _frames(2)
	await _frames(4)
	return _ok("the custodian dies (%s after %d plays)" % [cb.result, tries],
		cb.finished and cb.result == &"won")


func _check_loot(body: MapGen.Jetsam) -> void:
	if body == null:
		_fail("no body to look in")
		return
	var parts := 0
	var precursor := 0
	var branded_legendary := 0
	var ids := {}
	var shadow := false
	for it in body.items:
		if it is ModuleData:
			var m := it as ModuleData
			parts += 1
			ids[m.id] = true
			if m.rarity == ModuleData.Rarity.ARTIFACT:
				precursor += 1
			elif m.rarity == ModuleData.Rarity.LEGENDARY and m.manufacturer != &"":
				branded_legendary += 1
		elif it is MaterialData and (it as MaterialData).id == &"custodian_shadow":
			shadow = true
	print("    body: %s" % ", ".join(body.items.map(func(m: HoldItem) -> String:
		return "%s (%s%s)" % [m.name, ModuleData.Rarity.keys()[int(m.rarity)] if m is ModuleData else "material",
			(" " + String((m as ModuleData).manufacturer)) if m is ModuleData and (m as ModuleData).manufacturer != &"" else ""])))
	_ok("the body holds %d parts (want %d)" % [parts, Combat.CORE_PARTS], parts == Combat.CORE_PARTS)
	_ok("two precursor parts (%d)" % precursor, precursor == Combat.CORE_PRECURSOR)
	_ok("two branded legendary parts (%d)" % branded_legendary, branded_legendary == Combat.CORE_LEGENDARY)
	_ok("no part twice", ids.size() == parts)
	_ok("and the instrument shadow", shadow)
	# THE SAME BODY ON EVERY MACHINE: rolled by where it is, so a second roll at
	# the same place and wreck count holds the same parts in the same order.
	var again := MapGen.MapNode.new()
	again.index = Run.node_at().index
	var twin := Combat.core_body(again, DB.enemies[&"custodian"])
	var same := twin.items.size() == body.items.size()
	if same:
		for i in body.items.size():
			if body.items[i] is ModuleData and (twin.items[i] as ModuleData).id != (body.items[i] as ModuleData).id:
				same = false
	_ok("and it is rolled by place: the same body again at the same spot", same)


func _check_win_screen(when: String) -> void:
	var go := _win_screen()
	if not _ok("the win screen is up %s" % when, go != null):
		return
	_ok("  the loot step is over", not Router.final_loot)
	_ok("  it asks for the death screen's music (&\"gameover\")", Audio.music_asked == &"gameover")
	_ok("  it says YOU WON", _find(go, func(n: Node) -> bool:
		return n is Label and (n as Label).text == "YOU WON") != null)
	var card := go.card
	var tail := "\n\n<3\n\nJon"
	_ok("  Jon's note is on it, word for word", card != null
		and card.full_text == GameOverScreen.ALPHA_THANKS and card.full_text == AlphaNotes.ALPHA_THANKS
		and card.full_text.ends_with("the game of my dreams." + tail)
		and card.body.text + tail == AlphaNotes.ALPHA_THANKS)
	var heart := _find(go, func(n: Node) -> bool: return n.name == &"Heart")
	var sig := _find(go, func(n: Node) -> bool: return n.name == &"Signature") as Label
	_ok("  signed with the pixel heart, then JON", heart != null and sig != null and sig.text == "JON")
	var note: Control = card.body.get_parent_control() if card != null else null
	_ok("  the stats are on it", _find(go, func(n: Node) -> bool:
		return n is Label and (n as Label).text.contains("jumps ·")) != null)
	_ok("  with TITLE, NEW RUN and SAVE MY LOGS", _button(go, "TITLE") != null
		and _button(go, "NEW RUN") != null and _button(go, "SAVE MY LOGS") != null)
	var title_b := _button(go, "TITLE")
	_ok("  TITLE is the primary, on the amber plate", title_b != null
		and title_b.get_theme_font_size("font_size") == UITheme.FS_HEAD
		and title_b.get_theme_stylebox("normal") is StyleBoxTexture)
	_ok("  the note shows whole at the game's size (no scroll)", not go.note_scrolls())
	var screen := go.get_global_rect()
	var panel := go.panel_rect()
	print("    screen %s, panel %s, note scrolls: %s" % [screen, panel, go.note_scrolls()])
	_ok("  the panel is inside the screen", screen.grow(0.5).encloses(panel) and panel.size.y > 0.0)
	if note != null:
		var stats := _find(go, func(n: Node) -> bool:
			return n is Label and (n as Label).text.contains("jumps ·")) as Control
		var nr := note.get_parent_control().get_global_rect()
		_ok("  the note clears the stats and the buttons",
			stats != null and title_b != null
			and not nr.intersects(stats.get_global_rect())
			and not nr.intersects(title_b.get_global_rect()))
	_ok("  the HUD is back", Router.hud == null or Router.hud.visible)


## A fight that is not the custodian, won: no loot step, no win screen.
func _ordinary_fight() -> void:
	Rng.forced = 777
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var records_before := RunHistory.load_all().size()
	var idx := -1
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.SYSTEM and not n.cleared:
			idx = n.index
			break
	if not _ok("(ordinary) a system to fight at", idx >= 0):
		return
	Run.at = idx
	Run.map[idx].visited = true
	SectorScreen._approached_at = idx
	Router.show_local()
	await _frames(3)
	Router.start_combat(DB.enemies[&"cutter"], [], false, false)
	await _frames(3)
	var cb: Combat = Router.combat
	if not _ok("(ordinary) a cutter fight opens", cb != null):
		return
	var tries := 0
	while not cb.finished and tries < 30:
		tries += 1
		for e in cb.enemies:
			e.hp = mini(e.hp, 1)
			e.block = 0
		var played := false
		for i in cb.hand.size():
			if cb.can_play(cb.hand[i]):
				cb.play(i, 0)
				played = true
				break
		if not played and not cb.finished:
			cb.end_turn()
		await _frames(2)
	await _frames(6)
	_ok("(ordinary) the cutter dies", cb.result == &"victory")
	var sc := Router.current as SectorScreen
	_ok("(ordinary) you are left on LOCAL by its wreck", sc != null)
	_ok("(ordinary) no loot step and no popup forced open",
		not Router.final_loot and sc != null and not sc.has_open_container())
	_ok("(ordinary) no win screen", _win_screen() == null and not (Router.current is GameOverScreen))
	_ok("(ordinary) the run is not won", not Run.won)
	_ok("(ordinary) nothing new in the record", RunHistory.load_all().size() == records_before)
	_ok("(ordinary) the music is not the death cue", Audio.music_asked != &"gameover")


func _win_screen() -> GameOverScreen:
	var go := Router.current as GameOverScreen
	return go if go != null and Run.won else null


func _pause_menu() -> Node:
	return _find(_tree.root, func(n: Node) -> bool: return n is PauseMenu)


func _button(root: Node, text: String) -> Button:
	return _find(root, func(n: Node) -> bool:
		return n is Button and (n as Button).text == text and (n as Button).is_visible_in_tree()) as Button


func _find(root: Node, matches: Callable) -> Node:
	if root == null:
		return null
	if matches.call(root):
		return root
	for c in root.get_children():
		var f := _find(c, matches)
		if f != null:
			return f
	return null


func _press(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(1)


func _fail(why: String) -> void:
	print("  FAIL %s" % why)
	_fails += 1


func _finish() -> void:
	print("corewintest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)
