extends Node

## Jon, Oct 12: the boss body is lootable and ends the alpha with a win popup, death music.
## The custodian grows with the run (Nov 3), is built for the game's players (Nov 5) and is one galaxy-wide in co-op (Nov 4).
## Why: docs/why/CoreWinTest.md#core-win

var _tree: SceneTree
var harness := Harness.new()


func _ok(what: String, c: bool) -> bool:
	return harness._ok(what, c)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tree = get_tree()
	await Harness.frames(_tree, 2)

	_custodian_growth()
	_custodian_party()

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
	_ok("LOCAL says SALVAGE THE CUSTODIAN", sc != null and Harness.first(sc, func(n: Node) -> bool:
		return n is Button and (n as Button).text == "SALVAGE THE CUSTODIAN") != null)
	# QUIT HERE, AND COME BACK: the body, still to click
	_ok("a save is left on disk: the core with its body", FileAccess.file_exists(SaveGame.path))
	var records_mid := RunHistory.load_all().size()
	Router.final_loot = false
	Router.show_launcher()
	await Harness.frames(_tree, 3)
	Router.continue_run()
	await Harness.frames(_tree, 4)
	sc = Router.current as SectorScreen
	_ok("CONTINUE comes back to the core's LOCAL, the body waiting",
		sc != null and Router.final_loot and Run.won and Router.core_body_here() != null
		and not sc.has_open_container())
	_ok("and nothing more is recorded", RunHistory.load_all().size() == records_mid)
	# the body clicked, as its wreck is clicked
	var slot := _body_slot(sc)
	if _ok("the body is a wreck on LOCAL you can click", slot != null and slot.opened.is_valid()):
		slot.opened.call()
		await Harness.frames(_tree, 3)
	_ok("clicking the body opens its popup", sc != null and sc.has_open_container())
	_ok("the win screen is NOT up yet", _win_screen() == null)
	_ok("the HUD is hidden while the body is open",
		Router.hud == null or not Router.hud.visible)
	var tv: TransferView = sc._transfer if sc != null else null
	var body: MapGen.Jetsam = tv._jetsam if tv != null else null
	_ok("the popup is the custodian's body",
		body != null and body.art == &"custodian" and body == Router.core_body_here())
	_check_loot(body)
	# Every part can be seen: the popup sized the grid by count and pushed parts below the view.
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
	await Harness.frames(_tree, 3)
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
	await Harness.frames(_tree, 2)
	_ok("and the popup is still open after it", sc.has_open_container() and _win_screen() == null)

	var done := Harness.button_with_text(tv, "DONE")
	if not _ok("the popup has DONE", done != null):
		return _finish()
	done.pressed.emit()
	await Harness.frames(_tree, 4)
	_check_win_screen("after DONE")
	_ok("and the save is gone", not FileAccess.file_exists(SaveGame.path))
	_ok("the run is recorded once, not twice", RunHistory.load_all().size() == records_before + 1)
	# Escape on the win screen is the escape menu, and its ABANDON used to
	# write an ABANDONED record after the WON.
	await _press(KEY_ESCAPE)
	await Harness.frames(_tree, 3)
	var pm := _pause_menu() as PauseMenu
	if _ok("Escape on the win screen opens the escape menu", pm != null):
		pm.quit_requested.emit()
		await Harness.frames(_tree, 4)
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
		await Harness.frames(_tree, 4)
		_check_win_screen("after Escape")
		_ok("and no escape menu came up instead", _pause_menu() == null)

	# -------------------------------------------- three: a door left open
	core = await _to_core(5150)
	if await _beat_core():
		_ok("(third kill) the body waits", Router.final_loot)
		Router.show_system()
		await Harness.frames(_tree, 6)
		_check_win_screen("after leaving by another door")

	# ------------------------------------------------ an ordinary fight
	await _ordinary_fight()

	# ---------------------------------------- a party's Custodian, by Router
	await _party_router_fight()

	# ----------------------------------------------- the death screen's cue
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	await Harness.frames(_tree, 2)
	Audio.music_asked = &""
	Run.die("Hull integrity lost.")
	Router.show_game_over()
	await Harness.frames(_tree, 2)
	_ok("the death screen asks for &\"gameover\" too", Audio.music_asked == &"gameover")
	var go := Router.current as GameOverScreen
	# A TITLE button since Oct 22 (the audit: RUN ENDED's only way back was Esc,
	# then ABANDON); still no note
	_ok("and has no note, and a TITLE button", go != null
		and go.card == null and Harness.first(go, func(n: Node) -> bool: return n is NoteCard) == null
		and Harness.button_with_text(go, "TITLE") != null)
	_ok("the cue both screens ask for is Lights Out, played once",
		Audio.DEATH_CUE == &"lightsout" and Audio.DEATH_CUE in Audio.ONE_SHOT)
	_finish()


## G3 WITH CAP B, without a screen: the numbers, the fight they reach, and the
## template they must not change.
func _custodian_growth() -> void:
	var cust: EnemyTemplate = DB.enemies[&"custodian"]
	var want := {0: 200, 15: 200, 16: 208, 20: 243, 32: 390, 33: 400, 60: 400}
	var got := {}
	for j: int in want:
		got[j] = cust.hull_at(j)
	_ok("hull_at gives 200 to jump 15, then 208, 243, 390, 400 at 33, 400 at 60 (%s)" % str(got),
		got == want)
	# The cap holds however long the run: rounding before capping once gave
	# the most negative int past jump 994 (and at inf), so a 1-hull boss.
	var late := [994, 2000, 5000, 100000]
	var late_got := late.map(func(j: int) -> int: return cust.hull_at(j))
	_ok("and 400 at jumps 994, 2000, 5000 and 100000 (%s)" % str(late_got),
		late_got.all(func(h: int) -> bool: return h == 400))
	Rng.forced = 31337
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var fielded := {}
	for j: int in want:
		Run.jumps = j
		var cb := Combat.new()
		cb.plan(cust, 1)
		fielded[j] = cb.enemies[0].max_hp
	_ok("a Custodian fight fields the same hull at each jump count (%s)" % str(fielded),
		fielded == want)
	# Two fights in one process at 60, then one at 0: nothing adds up.
	var seq: Array = []
	for j in [60, 60, 0]:
		Run.jumps = j
		var cb := Combat.new()
		cb.plan(cust, 1)
		seq.append(cb.enemies[0].max_hp)
	var dmg: Array = []
	for i in cust.loop:
		dmg.append((i as IntentData).damage)
	_ok("fights at jumps 60, 60 and 0 field 400, 400, 200 (%s)" % str(seq), seq == [400, 400, 200])
	_ok("and the template still reads hull 200, brace 8, attacks 6 / 0 / 40 (%d, %d, %s)"
		% [cust.max_hull, cust.brace, str(dmg)],
		cust.max_hull == 200 and cust.brace == 8 and dmg == [6, 0, 40])
	# Hull only: the attacks a grown fight shows are the template's.
	Run.jumps = 60
	var big := Combat.new()
	big.plan(cust, 1)
	var big_dmg: Array = []
	for i in big.enemies[0].template.loop:
		big_dmg.append((i as IntentData).damage)
	_ok("a grown Custodian's attacks do not change (%s), nor its brace (%d)"
		% [str(big_dmg), big.enemies[0].brace], big_dmg == [6, 0, 40] and big.enemies[0].brace == 8)
	# Only the Custodian grows.
	var hulls: Array[int] = []
	for id in [&"lancer", &"hellbender"]:
		for j in [0, 60]:
			Run.jumps = j
			var cb := Combat.new()
			cb.plan(DB.enemies[id], 1)
			hulls.append(cb.enemies[0].max_hp)
	_ok("a lancer and the Hellbender field the same hull at jump 60 as at 0 (%s)" % str(hulls),
		hulls[0] == hulls[1] and hulls[2] == hulls[3])
	# CO-OP (Jon, Nov 5): the grown hull built for the players in the game,
	# and a joiner adds nothing
	Run.jumps = 33
	var op := Combat.new()
	op.plan(cust, 1, [], 2)
	var f := SharedFight.open(0, op.foe_ids(), op.foe_hp(), op.foe_brace(), op.foe_hp_now(), 1, -1, 2)
	var opened := f.foes[0].max_hp
	var two := PartyScale.party_hull(400, 2)
	f.join(2)
	_ok("co-op: at jump 33 a game of two fields 400 x %.2f = %d, and a joiner adds nothing (%d, %d)"
		% [PartyScale.hull(2), two, opened, f.foes[0].max_hp], opened == two and f.foes[0].max_hp == two and f.foes[0].hp == two)
	var hulls4: Array = []
	for n in [1, 2, 3, 4]:
		var c4 := Combat.new()
		c4.plan(cust, 1, [], n)
		hulls4.append(c4.enemies[0].max_hp)
	_ok("co-op: at jump 33 the Custodian for 1 to 4 players is %s" % str(hulls4),
		hulls4 == [400, PartyScale.party_hull(400, 2), PartyScale.party_hull(400, 3), PartyScale.party_hull(400, 4)])
	Run.jumps = 0


## Jon, Nov 4: strength and icon are the same for everyone, even late joiners, with no wire.
## Why: docs/why/CoreWinTest.md#custodian-growth
func _custodian_party() -> void:
	var cust: EnemyTemplate = DB.enemies[&"custodian"]
	Rng.forced = 31337
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_ok("a new run's lead ship count is 0, its count its own (%d, %d)" % [Run.party_jumps, Run.custodian_jumps()],
		Run.party_jumps == 0 and Run.custodian_jumps() == Run.jumps)
	# behind the lead: your jumps 5, the lead ship's 33
	Run.jumps = 5
	Run.party_jumps = 33
	var cb := Combat.new()
	cb.plan(cust, 1, [], 2)
	var f := SharedFight.open(0, cb.foe_ids(), cb.foe_hp(), cb.foe_brace(), cb.foe_hp_now(), 1, cb.grown, 2)
	var opened := f.foes[0].max_hp
	f.join(2)
	var two := PartyScale.party_hull(400, 2)
	_ok("co-op: at jump 5 behind a lead at 33 a game of two fields %d, grown at 33, and a joiner adds nothing (%d, %d, %d)"
		% [two, opened, cb.grown, f.foes[0].max_hp], opened == two and cb.grown == 33 and f.foes[0].max_hp == two)
	# and ahead of the lead's last word, your own jumps are the floor
	Run.jumps = 40
	Run.party_jumps = 20
	_ok("ahead of the lead ship's last word, the count is your own (%d)" % Run.custodian_jumps(), Run.custodian_jumps() == 40)
	# solo: the count is the jumps, and a fight with nothing that grows says -1
	Run.party_jumps = 0
	var seq: Array = []
	for j in [60, 60, 0]:
		Run.jumps = j
		var c2 := Combat.new()
		c2.plan(cust, 1)
		seq.append(c2.enemies[0].max_hp)
	var lancer := Combat.new()
	lancer.plan(DB.enemies[&"lancer"], 1)
	_ok("solo: fights at 60, 60 and 0 still field 400, 400, 200 (%s), and a lancer's says no count (%d)"
		% [str(seq), lancer.grown], seq == [400, 400, 200] and lancer.grown == -1)
	# Mid-fight: the host grows it, this machine adopts it, damage stays done, and the log says so.
	Run.jumps = 20
	var me := Combat.new()
	me.plan(cust, 1, [], 2)
	var sf := SharedFight.open(0, me.foe_ids(), me.foe_hp(), me.foe_brace(), me.foe_hp_now(), 1, me.grown, 2)
	sf.join(2)
	var said: Array = []
	var listen := func(text: String, _kind: StringName) -> void: said.append(text)
	Sig.log_line.connect(listen)
	me._attach(sf)
	sf.hurt(0, 120, 1, 1)
	me._adopt(sf)
	var done := me.enemies[0].max_hp - me.enemies[0].hp
	var quiet := said.filter(func(s: String) -> bool: return s.contains("grows stronger")).is_empty()
	var joined := sf.foes[0].max_hp
	sf.regrow(33, NetSession.growth_ratios(sf, 33))
	me._adopt(sf)
	var grown_by := me.enemies[0].max_hp
	var lines := said.filter(func(s: String) -> bool: return s == "The Custodian grows stronger.")
	_ok("mid-fight from 20 to 33: the hull bar rises from %d to %d (the two-player hull x hull_at(33) / hull_at(20)), the damage done (%d) stays done"
		% [joined, grown_by, done], grown_by == int(round(joined * float(cust.hull_at(33)) / float(cust.hull_at(20))))
		and joined == PartyScale.party_hull(cust.hull_at(20), 2)
		and me.enemies[0].max_hp - me.enemies[0].hp == done and done > 0)
	_ok("and the log says \"The Custodian grows stronger.\" once, never on joining (%d; %s)" % [lines.size(), "quiet" if quiet else "said early"],
		lines.size() == 1 and quiet and me.grown == 33)
	me._adopt(sf)
	_ok("and not again for the same count", said.filter(func(s: String) -> bool: return s == "The Custodian grows stronger.").size() == 1)
	me.release()
	# Asleep and capped counts grow no hull and say nothing. The wake itself says it.
	for row: Array in [[7, 8, false], [8, 16, true], [33, 40, false]]:
		said.clear()
		Run.jumps = int(row[0])
		var c3 := Combat.new()
		c3.plan(cust, 1)
		var f3 := SharedFight.open(0, c3.foe_ids(), c3.foe_hp(), c3.foe_brace(), c3.foe_hp_now(), 1, c3.grown)
		c3._attach(f3)
		var hull0 := c3.enemies[0].max_hp
		f3.regrow(int(row[1]), NetSession.growth_ratios(f3, int(row[1])))
		c3._adopt(f3)
		var told := said.any(func(s: String) -> bool: return s.contains("grows stronger"))
		var grew := c3.enemies[0].max_hp > hull0
		_ok("%d to %d mid-fight: the hull %s (%d to %d) and the log %s" % [row[0], row[1],
			"grows" if grew else "stays", hull0, c3.enemies[0].max_hp, "says so" if told else "says nothing"],
			told == bool(row[2]) and grew == bool(row[2]) and c3.grown == int(row[1])
			and (not told or said.has("The Custodian grows stronger.")))
		c3.release()
	# Joining an already grown fight: adopted on attaching, so nothing is said.
	said.clear()
	Run.jumps = 17
	var late := Combat.new()
	late.plan(cust, 1)
	var lf := SharedFight.open(0, late.foe_ids(), late.foe_hp(), late.foe_brace(), late.foe_hp_now(), 1, late.grown)
	lf.regrow(20, NetSession.growth_ratios(lf, 20))
	late._attach(lf)
	late._adopt(lf)
	var late_told := said.any(func(s: String) -> bool: return s.contains("grows stronger"))
	_ok("a ship planned at 17 joining a fight grown to 20 says nothing (%s), takes its count (%d) and its hull (%d, %d)" % [
		"said it" if late_told else "quiet", late.grown, late.enemies[0].max_hp, lf.foes[0].max_hp],
		not late_told and late.grown == 20 and late.enemies[0].max_hp == lf.foes[0].max_hp)
	late.release()
	Sig.log_line.disconnect(listen)
	Run.jumps = 0
	Run.party_jumps = 0


## The wreck slot on LOCAL that is the custodian's body.
func _body_slot(sc: SectorScreen) -> EnemySlot:
	if sc == null:
		return null
	return Harness.first(sc, func(n: Node) -> bool:
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
	await Harness.frames(_tree, 3)
	return idx


## ENGAGE, then the custodian played to a kill. True when the fight ended in
## the run's win.
func _beat_core() -> bool:
	Router.engage_here()
	for i in 30:
		if Router.combat != null and not Router.combat.enemies.is_empty():
			break
		await Harness.frames(_tree, 1)
	var cb: Combat = Router.combat
	if not _ok("ENGAGE at the core opens a fight", cb != null and not cb.enemies.is_empty()):
		return false
	var t: EnemyTemplate = cb.enemies[0].template
	_ok("against the custodian, a boss", t.id == &"custodian" and t.boss)
	# jump 41 is past the cap, so the hull it opens with is twice its 200
	_ok("which opens at hull 400 at jump %d, before the test cuts it (%d)"
		% [Run.jumps, cb.enemies[0].max_hp],
		Run.jumps == 41 and cb.enemies[0].max_hp == 400 and cb.enemies[0].hp == 400)
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
		await Harness.frames(_tree, 2)
	await Harness.frames(_tree, 4)
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
	_ok("  it says YOU WON", Harness.first(go, func(n: Node) -> bool:
		return n is Label and (n as Label).text == "YOU WON") != null)
	var card := go.card
	var tail := "\n\n<3\n\nJon"
	_ok("  Jon's note is on it, word for word", card != null
		and card.full_text == GameOverScreen.ALPHA_THANKS and card.full_text == AlphaNotes.ALPHA_THANKS
		and card.full_text.ends_with("the game of my dreams." + tail)
		and card.body.text + tail == AlphaNotes.ALPHA_THANKS)
	var heart := Harness.first(go, func(n: Node) -> bool: return n.name == &"Heart")
	var sig := Harness.first(go, func(n: Node) -> bool: return n.name == &"Signature") as Label
	_ok("  signed with the pixel heart, then JON", heart != null and sig != null and sig.text == "JON")
	var note: Control = card.body.get_parent_control() if card != null else null
	_ok("  the stats are on it", Harness.first(go, func(n: Node) -> bool:
		return n is Label and (n as Label).text.contains("jumps ·")) != null)
	_ok("  with TITLE, NEW RUN and SAVE MY LOGS", Harness.button_with_text(go, "TITLE") != null
		and Harness.button_with_text(go, "NEW RUN") != null and Harness.button_with_text(go, "SAVE MY LOGS") != null)
	var title_b := Harness.button_with_text(go, "TITLE")
	_ok("  TITLE is the primary, on the amber plate", title_b != null
		and title_b.get_theme_font_size("font_size") == UITheme.FS_HEAD
		and title_b.get_theme_stylebox("normal") is StyleBoxTexture)
	_ok("  the note shows whole at the game's size (no scroll)", not go.note_scrolls())
	var screen := go.get_global_rect()
	var panel := go.panel_rect()
	print("    screen %s, panel %s, note scrolls: %s" % [screen, panel, go.note_scrolls()])
	_ok("  the panel is inside the screen", screen.grow(0.5).encloses(panel) and panel.size.y > 0.0)
	if note != null:
		var stats := Harness.first(go, func(n: Node) -> bool:
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
	await Harness.frames(_tree, 3)
	Router.start_combat(DB.enemies[&"cutter"], [], false, false)
	await Harness.frames(_tree, 3)
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
		await Harness.frames(_tree, 2)
	await Harness.frames(_tree, 6)
	_ok("(ordinary) the cutter dies", cb.result == &"victory")
	var sc := Router.current as SectorScreen
	_ok("(ordinary) you are left on LOCAL by its wreck", sc != null)
	_ok("(ordinary) no loot step and no popup forced open",
		not Router.final_loot and sc != null and not sc.has_open_container())
	_ok("(ordinary) no win screen", _win_screen() == null and not (Router.current is GameOverScreen))
	_ok("(ordinary) the run is not won", not Run.won)
	_ok("(ordinary) nothing new in the record", RunHistory.load_all().size() == records_before)
	_ok("(ordinary) the music is not the death cue", Audio.music_asked != &"gameover")


## WHAT THE LOG SAYS IS WHAT WAS MADE (review, Nov 5): in a game of three a
## material is paid three times (`add_material`, `PartyScale.pay`), and the
## line says three, not the one a lone pilot gets.
func _logs_say_what_was_made() -> void:
	var said: Array[String] = []
	var hear := func(text: String, _kind: StringName) -> void: said.append(text)
	Sig.log_line.connect(hear)
	var k := PartyScale.pay(1)
	# a found hull scrapped: its crates
	Run.found_hull = DB.hull_for(&"korvan", HullData.Weight.LIGHT).duplicate() as HullData
	Run.found_scrap = {credits = 30, material = &"deck_plate"}
	var pile0 := Run.sector_jetsam(Run.node_at()).items.size()
	Run.scrap_found_hull()
	var made := Run.sector_jetsam(Run.node_at()).items.size() - pile0
	var mat_name := String(MaterialTable.by_id(&"deck_plate").get("name", "?"))
	var line := ""
	for t in said:
		if t.begins_with("Scrapped"):
			line = t
	_ok("(party) scrapping a found hull in a game of %d makes %d crates and the log says so: \"%s\"" % [PartyScale.players(), made, line],
		k == 3 and made == 3 and line.ends_with(" %d crates of %s are in SECTOR LOOT." % [made, mat_name]))
	# a pulsar's beam: what it leaves adrift (`harvest_pulsar` reads the
	# system's danger and nothing of its kind, so any system but this one does
	# when the map has no pulsar)
	var p: MapGen.MapNode = null
	for raw in Run.map:
		if (raw as MapGen.MapNode).type == MapGen.NodeType.PULSAR:
			p = raw
			break
	if p == null:
		for raw in Run.map:
			if (raw as MapGen.MapNode).index != Run.at and (raw as MapGen.MapNode).danger >= 4:
				p = raw
				break
	if _ok("(party) a system to fly the beam in", p != null):
		var was_cleared := p.cleared
		p.cleared = false
		var at0 := Run.at
		var kept := [Run.hp, Run.fuel, Run.heat]
		Run.at = p.index
		Run.hp = Run.max_hp()
		said.clear()
		var silt0 := Run.sector_jetsam(p).items.size()
		Run.harvest_pulsar()
		var adrift := Run.sector_jetsam(p).items.size() - silt0
		var said_n := -1
		for t in said:
			if t.contains(" adrift alongside."):
				said_n = int(t.split(", and ")[1].split(" ")[0])
		_ok("(party) a pulsar's beam leaves %d adrift in a game of three and the log says %d" % [adrift, said_n],
			adrift == PartyScale.pay(1 + int(p.danger / 4)) and adrift > 1 and said_n == adrift)
		p.cleared = was_cleared
		Run.at = at0
		Run.hp = int(kept[0])
		Run.fuel = int(kept[1])
		Run.heat = int(kept[2])
	Sig.log_line.disconnect(hear)


## `Router.start_combat` on a host hands `Combat.grown` to `Net.open_fight` (PROTOCOL 16).
## Why: docs/why/CoreWinTest.md#party-fight-count
func _party_router_fight() -> void:
	Rng.forced = 777
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var idx := -1
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.SYSTEM and not n.cleared:
			idx = n.index
			break
	if not _ok("(party) a system to fight at", idx >= 0):
		return
	Run.at = idx
	Run.map[idx].visited = true
	SectorScreen._approached_at = idx
	Router.show_local()
	await Harness.frames(_tree, 3)
	var t := DirectTransport.new()
	t.port = DirectTransport.DEFAULT_PORT + 19
	t.advertise = "127.0.0.1"
	if not _ok("(party) the game's session hosts a party", Net.host_party("Kevin", &"korvan", t) != ""):
		return
	Net.roster[777] = Net._slot(777, "Mercer", &"korvan", 1)
	Net.dive_seed = Run.galaxy_seed
	Net._set_state(NetSession.State.DIVING)
	_ok("(party) in the dive on its galaxy the tooltip says the party's words", CustodianBadge.party())
	Net.dive_seed = Run.galaxy_seed + 1
	_ok("(party) on a NEW RUN's galaxy, still in the party, the solo words", not CustodianBadge.party())
	Net.dive_seed = Run.galaxy_seed
	Run.jumps = 5
	Run.party_jumps = 20
	Router.start_combat(DB.core_boss(), [], false, true)
	await Harness.frames(_tree, 3)
	var cb: Combat = Router.combat
	var f := Net.fight_at(idx)
	var want := Run.custodian_jumps()
	var h20 := DB.core_boss().hull_at(20)
	var h20x2 := PartyScale.party_hull(h20, 2)
	_ok("(party) Router opens the party's Custodian with its count: the fight's %d, Combat's %d, want %d, hull %d of %d (hull_at(20) x %.2f for two)" % [
		f.grown if f != null else -2, cb.grown if cb != null else -2, want, f.foes[0].max_hp if f != null else -1, h20x2, PartyScale.hull(2)],
		f != null and cb != null and want == 20 and f.grown == want and cb.grown == want
		and f.foes[0].max_hp == h20x2 and f.party == 2 and cb.party == 2 and Net.galaxy_jumps == want)
	# ONE CUSTODIAN FOR THE GALAXY, AND ONE PARTY SIZE (Jon, Nov 4 and 5): the
	# badge shows the lead ship's jumps, the same for every pilot whatever the
	# party's size; the size is the host's count, the same for every pilot too
	_ok("(party) the badge's count is the lead ship's jumps, not the party's size (%d)" % CustodianBadge.count(),
		CustodianBadge.count() == want)
	if cb != null:
		cb.release()
	Router.combat = null
	# A THIRD PLAYER ARRIVES: the fight open keeps its numbers, the next
	# Custodian is built for three; the badge does not move
	Net.leave_fight(idx)
	Net.roster[778] = Net._slot(778, "Vela", &"korvan", 2)
	Router.start_combat(DB.core_boss(), [], false, true)
	await Harness.frames(_tree, 3)
	var f3 := Net.fight_at(idx)
	_ok("(party) with a third player the next Custodian is built for three (%d, want %d), the badge still %d" % [
		f3.foes[0].max_hp if f3 != null else -1, PartyScale.party_hull(h20, 3), CustodianBadge.count()],
		f3 != null and f3 != f and f3.party == 3 and f3.foes[0].max_hp == PartyScale.party_hull(h20, 3)
		and CustodianBadge.count() == want)
	if Router.combat != null:
		Router.combat.release()
	Router.combat = null
	await _logs_say_what_was_made()
	Net.leave_party()
	Net.dive_seed = 0
	Run.jumps = 0
	Run.party_jumps = 0
	await Harness.frames(_tree, 2)


func _win_screen() -> GameOverScreen:
	var go := Router.current as GameOverScreen
	return go if go != null and Run.won else null


func _pause_menu() -> Node:
	return Harness.first(_tree.root, func(n: Node) -> bool: return n is PauseMenu)


func _press(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await Harness.frames(_tree, 1)


func _fail(why: String) -> void:
	harness._fail(why)


func _finish() -> void:
	harness.verdict("corewintest")
	_tree.quit(harness.code())
