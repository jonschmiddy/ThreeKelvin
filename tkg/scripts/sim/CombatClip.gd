extends Node

## A FIGHT, PLAYED THE WAY A PLAYER PLAYS IT, AND FILMED (combat polish audit,
## Oct 13). Every card goes through the real gesture -- a pointer rests on it,
## presses, carries it up out of the drawer, holds over the target long enough
## to read the preview, lets go -- pushed into the game's own viewport, so the
## aim line, the lift, the readout and the targeting brackets are all the ones a
## person gets. END TURN, FLEE, HAIL and the confirm panels are clicked the same
## way. Nothing calls `Combat.play` behind the screen's back.
##
##   godot --path . --fixed-fps 30 --windowed --position 3840,0 -- sheet=CombatClip
##       out=<dir> fight=<id>[,<id>...] [end=win|lose|flee|hail] [seed=N]
##       [manufacturer=korvan] [weight=light|medium|heavy] [danger=N] [hp=N] [heat=N]
##       [after=150] [maxframes=N] [nofilm] [timing] [hints] [rest]
##       [prefer=defence] [youblock=N]
##
## `out=<dir>` gets `f_####.png` (the window as seen: 1920x1080, the game at
## 2x), `events.json` (every signal that matters, by frame: card released, shot
## landed, damage resolved, bar moved, turn, the end) and `tape.json` (every
## sound `Audio` actually played, by frame). `nofilm` saves no pictures;
## `timing` (run WITHOUT --fixed-fps) records each real frame's length, so a
## stall on a card play shows up as a number rather than a hunch.
##
## A software pointer is drawn over the game (an arrow, hidden while the aim's
## reticle is the pointer, as the game hides the real one), because a pushed
## event moves no hardware cursor and a film without one shows cards moving by
## themselves.
##
## `end=win` plays `Policy`'s best card every time it has one, else END TURN.
## `end=lose` plays nothing and ends turns until the hull goes (start it low
## with `hp=`). `end=flee` / `end=hail` open the exit on turn one and take it.
## `rest` holds the pointer still on the first card for 1.4 s, so its keyword
## panel opens. `hints` lets the first-run hints show (they are reset first, in
## the harness's own settings file).

var _args: PackedStringArray
var _dir := ""
var _film := true
var _timing := false
var _frame := 0
var _live := true
var _events: Array = []
var _frame_ms: Array = []
var _wall_at_frame: Array = []
var _pending: Array[int] = []
var _ptr: Vector2 = Vector2(480, 300)
var _ptr_down := false
var _cursor: Ptr = null
var _sc: SectorScreen = null
var _cb: Combat = null
var _last_usec := 0


class Ptr extends Control:
	var at := Vector2.ZERO
	var hide_it := false

	func _draw() -> void:
		if hide_it:
			return
		# A plain pixel arrow, black edged, 1:1 in the game's pixels.
		var rows := [
			"X",
			"XX",
			"XWX",
			"XWWX",
			"XWWWX",
			"XWWWWX",
			"XWWWWWX",
			"XWWWWWWX",
			"XWWWWXXXX",
			"XWXWWX",
			"XX XWWX",
			"X   XWWX",
			"     XX",
		]
		for y in rows.size():
			var r: String = rows[y]
			for x in r.length():
				var ch := r[x]
				if ch == "X":
					draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), Color("#05070a"))
				elif ch == "W":
					draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), Color("#f2f4f6"))


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _has(k: String) -> bool:
	return k in _args


func _log(ev: String, extra: Dictionary = {}) -> void:
	var d := {f = _frame, ev = ev}
	d.merge(extra)
	_events.append(d)
	print("  [%4d] %s %s" % [_frame, ev, JSON.stringify(extra) if not extra.is_empty() else ""])


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	_dir = _arg("out")
	_film = _dir != "" and not _has("nofilm")
	_timing = _has("timing")
	if _dir != "":
		DirAccess.make_dir_recursive_absolute(_dir)
	Router.animate_in_harness = true
	Audio.taping = true
	# `handoff=A|B|C`: which way a death goes into RUN ENDED (`DeathHandoff`)
	SectorScreen.handoff_override = _arg("handoff", "")
	if _has("hints"):
		Hints.forced = true
		Hints.reset()

	Rng.forced = int(_arg("seed", "4242"))
	var weight := {"light": HullData.Weight.LIGHT, "medium": HullData.Weight.MEDIUM,
		"heavy": HullData.Weight.HEAVY}.get(_arg("weight", "medium"), HullData.Weight.MEDIUM) as int
	Run.start_new_run(StringName(_arg("manufacturer", "korvan")), weight)
	var idx := -1
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.SYSTEM and not n.cleared:
			idx = n.index
			break
	if idx < 0:
		print("combatclip: no system to fight at")
		tree.quit(1)
		return
	Run.at = idx
	Run.map[idx].visited = true
	if _arg("danger") != "":
		Run.map[idx].danger = int(_arg("danger"))
	SectorScreen._approached_at = idx
	Router.show_local()
	_overlay(tree)
	_watch()
	_record.call()
	for i in 40:
		await _tick()
	if _arg("hp") != "":
		Run.hp = int(_arg("hp"))
	if _arg("heat") != "":
		Run.heat = int(_arg("heat"))
	var ids := _arg("fight", "cutter").split(",")
	var extras: Array = []
	for i in range(1, ids.size()):
		extras.append(DB.enemies[StringName(ids[i])])
	_log("start_combat", {foes = ids, danger = Run.node_at().danger, hp = Run.hp,
		max_hp = Run.max_hp(), heat = Run.heat, cap = Run.heat_cap(), reactor = Run.reactor(),
		hand = Run.hand_size()})
	Router.start_combat(DB.enemies[StringName(ids[0])], extras, false, false)
	await tree.process_frame
	_cb = Router.combat
	_sc = Router.current as SectorScreen
	if _cb == null or _sc == null:
		print("combatclip: no fight opened")
		_live = false
		tree.quit(1)
		return
	_hook_fight()
	# `foehp=N`: every contact opens at no more than N hull, so a long fight
	# (the core's guard) can be filmed to its end without the model losing it.
	if _arg("foehp") != "":
		for e0 in _cb.enemies:
			(e0 as Combat.EnemyState).hp = mini((e0 as Combat.EnemyState).hp, int(_arg("foehp")))
		_cb.enemies[0].pick_intent()
		Sig.enemy_changed.emit()
	for e in _cb.enemies:
		var es: Combat.EnemyState = e
		_log("foe", {name = es.template.name, hp = es.hp, brace = es.brace,
			intent = es.intent.name if es.intent != null else "",
			text = es.intent.text if es.intent != null else "",
			dmg = es.intent.damage if es.intent != null else 0,
			hits = es.intent.hits if es.intent != null else 0,
			block = es.intent.block if es.intent != null else 0})
	# The fight's opening: let the contacts fly in and the hand deal.
	await _wait(45)
	# `youblock=N`: N block on your ship now, as a card would give it (a deck
	# may hold no block card), so a film shows your bubble come up and take hits
	if _arg("youblock") != "":
		_cb.block += int(_arg("youblock"))
		_log("you_block", {block = _cb.block})
		Sig.player_combat_state_changed.emit()
		await _wait(30)

	var end := _arg("end", "win")
	var cap := int(_arg("maxframes", "2400"))
	var pol := Policy.new()
	var rested := false
	while not _cb.finished and _frame < cap:
		if end == "flee" or end == "hail":
			await _take_exit(end)
			break
		if end == "lose":
			await _click(_sc._end_button)
			await _wait(40)
			continue
		await _settle()
		if _cb.finished:
			break
		var pick := pol.best_card(_cb)
		# `prefer=defence`: a playable block or brace card first, so a film
		# shows your bubble and your armour (HitLayers)
		if _arg("prefer") == "defence":
			for k in _cb.hand.size():
				var hc: CardData = _cb.hand[k]
				if (hc.block > 0 or hc.brace > 0) and _cb.can_play(hc):
					pick = k
					break
		if pick < 0:
			await _wait(10)
			await _click(_sc._end_button)
			await _wait(45)
			continue
		await _play(pick, _has("rest") and not rested)
		rested = true
		await _wait(24)

	_log("loop_done", {finished = _cb.finished, result = _cb.result})
	# The ending as it plays out: the panel, the router's swap, the next screen.
	var after := int(_arg("after", "150"))
	var lost_logged := false
	for i in after:
		await _tick()
		# Your own ship's breakup, when the fight killed you (`ShipLoss`).
		if not lost_logged and is_instance_valid(_sc) and _sc.loss != null:
			lost_logged = true
			_log("ship_lost", {style = String(ShipBreakup.NAMES.get(_sc.loss.style, "?")),
				secs = _sc.loss.duration, boss = _sc.loss.boss})
	# A panel left waiting for CONTINUE is part of what the player has to do.
	if is_instance_valid(_sc) and _sc.is_inside_tree():
		var cont := _find_button(_sc, "CONTINUE")
		if cont != null and cont.is_visible_in_tree():
			await _click(cont)
			for i in 90:
				await _tick()
	var cur := Router.current
	_log("final_screen", {screen = cur.get_script().get_global_name() if cur != null else "none",
		hp = Run.hp, heat = Run.heat, fuel = Run.fuel, credits = Run.credits})
	_live = false
	await tree.process_frame
	_finish()
	tree.quit()


func _finish() -> void:
	# Every picture written before anything is reported done.
	for t in _pending:
		WorkerThreadPool.wait_for_task_completion(t)
	if _dir == "":
		return
	var tape: Array = []
	for row in Audio.tape:
		var ms: int = row[1]
		var f := 0
		for i in _wall_at_frame.size():
			if int(_wall_at_frame[i]) <= ms:
				f = i
		tape.append({name = String(row[0]), ms = ms, f = f, db = row[2]})
	var out := {events = _events, tape = tape, frames = _frame,
		frame_ms = _frame_ms if _timing else []}
	var fa := FileAccess.open(_dir + "/events.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify(out, "  "))
	fa.close()
	print("combatclip: %d frames, %d events, %d sounds -> %s" % [_frame, _events.size(), tape.size(), _dir])


## Every frame, after it is drawn: its picture, its real length, the clock.
func _record() -> void:
	_last_usec = Time.get_ticks_usec()
	while _live:
		await _tick()
		var now := Time.get_ticks_usec()
		_wall_at_frame.append(Time.get_ticks_msec())
		if _timing:
			_frame_ms.append(snappedf((now - _last_usec) / 1000.0, 0.01))
		_last_usec = now
		if _cursor != null:
			_cursor.at = _ptr
			_cursor.hide_it = _sc != null and is_instance_valid(_sc) and _sc._cursor_off
			_cursor.queue_redraw()
		if _film:
			var img := get_tree().root.get_texture().get_image()
			var path := "%s/f_%04d.png" % [_dir, _frame]
			_pending.append(WorkerThreadPool.add_task(func() -> void: img.save_png(path)))
		_frame += 1


func _overlay(tree: SceneTree) -> void:
	var vp := GameShell.input_target(tree)
	var layer := CanvasLayer.new()
	layer.layer = 127
	vp.add_child(layer)
	_cursor = Ptr.new()
	_cursor.size = Vector2(960, 540)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_cursor)


func _watch() -> void:
	Sig.card_played.connect(func(c: CardData) -> void:
		_log("card_played", {card = c.name, dmg = c.damage, hits = c.hits, heat = c.heat,
			energy = c.energy, block = c.block, brace = c.brace}))
	Sig.damage_dealt.connect(func(amount: int, to_player: bool, who: int) -> void:
		_log("damage_resolved", {amount = amount, to_player = to_player, who = who,
			player_hp = Run.hp}))
	Sig.enemy_destroyed.connect(func(who: int) -> void: _log("enemy_destroyed", {who = who}))
	Sig.turn_started.connect(func(t: int) -> void:
		_log("turn_started", {turn = t, energy = _cb.energy if _cb != null else -1,
			hand = _cb.hand.size() if _cb != null else -1, hp = Run.hp, heat = Run.heat}))
	Sig.combat_ended.connect(func(r: StringName, text: String) -> void:
		_log("combat_ended", {result = String(r), text = text}))
	Sig.overheated.connect(func(b: int) -> void: _log("overheated", {burn = b}))
	# The screen's own clock (combat polish): every attack as resolved, every
	# volley as SEEN landing, every self-inflicted burn.
	Sig.combat_hit.connect(func(tp: bool, who: int, dealt: int, ab: int, mi: int, hits: int) -> void:
		_log("combat_hit", {to_player = tp, who = who, dealt = dealt, absorbed = ab, missed = mi, hits = hits}))
	Sig.hit_landed.connect(func(amount: int, tp: bool, who: int, ab: int) -> void:
		_log("hit_landed", {amount = amount, to_player = tp, who = who, absorbed = ab}))
	Sig.hull_burned.connect(func(amount: int, cause: StringName) -> void:
		_log("hull_burned", {amount = amount, cause = String(cause)}))
	Sig.screen_changed.connect(func() -> void:
		var cur := Router.current
		_log("screen_changed", {screen = cur.get_script().get_global_name() if cur != null else "none"}))
	Sig.enemy_changed.connect(func() -> void:
		if _cb == null:
			return
		var hp: Array = []
		var intents: Array = []
		for e in _cb.enemies:
			hp.append((e as Combat.EnemyState).hp)
			var it: IntentData = (e as Combat.EnemyState).intent
			intents.append("%s|%s|dmg %d x%d|blk %d" % [it.name, it.text, it.damage, it.hits, it.block] if it != null else "")
		_log("enemy_changed", {hp = hp, intents = intents}))


func _hook_fight() -> void:
	if _sc._view != null and _sc._view.fx != null:
		_sc._view.fx.landed.connect(func(who: int, to_player: bool, kind: int) -> void:
			_log("shot_landed", {who = who, to_player = to_player, kind = kind}))


## After the frame is drawn in a window; headless never draws, so a plain frame.
func _tick() -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw


## Wait, as a player would, while the screen is still playing something out
## (a turn being shown, the opening deal). Logs how long it took.
func _settle() -> void:
	if _sc == null or not is_instance_valid(_sc):
		return
	var n := 0
	while is_instance_valid(_sc) and _sc.is_inside_tree() and ("_hold" in _sc) 			and (_sc._hold or _sc._opening) and n < 600:
		await get_tree().process_frame
		n += 1
	if n > 0:
		_log("settled", {frames = n})


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _push(at: Vector2, down: bool, button: bool) -> void:
	var vp := GameShell.input_target(get_tree())
	if button:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = down
		mb.position = at
		mb.global_position = at
		mb.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		vp.push_input(mb)
		_ptr_down = down
	else:
		var mm := InputEventMouseMotion.new()
		mm.position = at
		mm.global_position = at
		mm.relative = at - _ptr
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT if _ptr_down else 0
		vp.push_input(mm)
	_ptr = at


## The pointer travels, eased, over `frames` frames, the way a hand does.
func _glide(to: Vector2, frames: int) -> void:
	var from := _ptr
	for i in frames:
		var u := float(i + 1) / float(frames)
		var e := u * u * (3.0 - 2.0 * u)
		_push(from.lerp(to, e).round(), false, false)
		await get_tree().process_frame


func _click(c: Control) -> void:
	if c == null or not is_instance_valid(c):
		_log("click_missing")
		return
	var at := c.get_global_rect().get_center().round()
	await _glide(at, 14)
	c.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await _wait(6)
	var hov := GameShell.input_target(get_tree()).gui_get_hovered_control()
	_log("click", {what = (c as Button).text if c is Button else c.get_class(),
		disabled = (c as Button).disabled if c is Button else false,
		at = [at.x, at.y], under = str(hov.get_path()) if hov != null else "none"})
	# PUSHED EVENTS DO NOT PRESS A BUTTON. A card takes its press through its own
	# `gui_input` and the screen's `_input`, and those work from a pushed event;
	# `BaseButton` decides "released inside" from the viewport's pointer, which a
	# pushed event into the game's SubViewport does not move (SectorShot calls the
	# handlers directly for the same reason). So the press is pushed -- the button
	# shows its pressed face -- and if it did not fire, the release is delivered
	# the one way that reaches it. Logged either way.
	var fired := [false]
	var b := c as Button
	var mark := func() -> void: fired[0] = true
	if b != null:
		b.pressed.connect(mark)
	_push(at, true, true)
	await _wait(3)
	_push(at, false, true)
	if b != null and is_instance_valid(b):
		b.notification(Control.NOTIFICATION_MOUSE_EXIT)
		if not fired[0] and not b.disabled and b.is_visible_in_tree():
			b.pressed.emit()
			_log("click_delivered", {what = b.text})
		if b.pressed.is_connected(mark):
			b.pressed.disconnect(mark)
	await _wait(2)


func _view_of(card: CardData) -> CardView:
	for v in _sc._hand._views:
		if v != null and is_instance_valid(v) and v.card == card:
			return v
	return null


func _play(pick: int, rest: bool) -> void:
	var card: CardData = _cb.hand[pick]
	var v := _view_of(card)
	if v == null:
		_log("no_view", {card = card.name})
		await _click(_sc._end_button)
		return
	var aim_enemy := card.damage > 0 or card.damage_equals_heat or card.evoke > 0
	var target := Vector2.ZERO
	var tgt_i := -1
	if aim_enemy:
		var best := 1 << 30
		for i in _cb.enemies.size():
			var e: Combat.EnemyState = _cb.enemies[i]
			if e.hp > 0 and e.hp < best:
				best = e.hp
				tgt_i = i
		var sl := _sc._view.slot(tgt_i)
		target = sl.holder_rect().get_center()
	else:
		target = _sc._view.ship_view().get_global_rect().get_center()
	var r := v.get_global_rect()
	var on := Vector2(r.get_center().x, r.position.y + r.size.y * 0.55).round()
	await _glide(on, 16)
	# THE HOVER, BY HAND. A pushed event does not move the viewport's own idea of
	# where the pointer is, so Godot never sends `mouse_entered`; the card is told
	# directly, the way `SectorShot` points at things. That is what lifts it and
	# starts the keyword panel's clock.
	v.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await _wait(42 if rest else 12)
	# A card still being dealt has moved since the pointer set off for it.
	if not is_instance_valid(v):
		return
	r = v.get_global_rect()
	var now := Vector2(r.get_center().x, r.position.y + r.size.y * 0.55).round()
	if now.distance_to(on) > 2.0:
		on = now
		await _glide(on, 4)
	_log("press", {card = card.name, target = tgt_i})
	_push(on, true, true)
	await _wait(3)
	# Up and out of the drawer first, then across to the target.
	var lift := Vector2(on.x, _sc._hand.get_global_rect().position.y - 30.0)
	await _glide(lift, 8)
	await _glide(target.round(), 14)
	# Long enough to read the number painted on the target.
	await _wait(20)
	_log("release", {card = card.name, target = tgt_i})
	_push(_ptr, false, true)
	await _wait(2)
	# Park the pointer off the board, the way a hand comes back to the fan.
	await _glide(Vector2(_ptr.x, 470), 10)


func _find_button(root: Node, text: String) -> Button:
	# VISIBLE ONLY. The screen keeps a hidden full-screen overlay with its own
	# CONTINUE; pressing that one mid-fight is not something a player can do.
	if root is Button and (root as Button).text == text and (root as Button).is_visible_in_tree():
		return root
	for c in root.get_children():
		var b := _find_button(c, text)
		if b != null:
			return b
	return null


func _take_exit(kind: String) -> void:
	await _wait(20)
	var b: Button = _sc._flee_button if kind == "flee" else _sc._hail_button
	await _click(b)
	await _wait(50)
	var go_label := "BREAK CONTACT" if kind == "flee" else "HAIL THEM"
	var go := _find_button(_sc, go_label)
	if go == null:
		_log("no_go_button", {label = go_label})
		return
	await _click(go)
	await _wait(75)
	_log("exit_taken", {finished = _cb.finished, result = _cb.result, fuel = Run.fuel,
		heat = Run.heat, note = _cb.exit_note})
	if not _cb.finished:
		# It failed: the panel says so, and the fight goes on. Close it.
		var cont := _find_button(_sc, "CONTINUE")
		if cont != null:
			await _click(cont)
		await _wait(60)
