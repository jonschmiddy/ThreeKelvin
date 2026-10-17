extends Node

## A NEW PLAYER'S FIRST RUN, filmed: from the title screen to the first
## fight won and its wreck looted, clicked the way a new player clicks. Made for
## the tutorial audit (Oct 17) and kept as the sheet that re-films it, so a
## change to how the game teaches itself is measured against the same seed and
## the same bot. Run under the movie writer for a film with sound:
##   godot --path . --resolution 1920x1080 --write-movie <dir>/film.avi --fixed-fps 30
##       -- sheet=FirstRunFilm welcome hints asrelease out=<dir> [seed=N]
## Prints `mark <name> <frame> <game_s>` at each teaching moment and writes
## `<out>/marks.json`: FIRST CONTROL (the ship stopped, the controls yours), the
## first card, every click and which only put something away. Reading pauses are
## modelled at READ_WPS words a second: the welcome note skimmed, each hint and
## the goal line read in full, then the click the player was going to make
## anyway. The pointer is a software arrow (CombatClip's), since pushed events
## move no hardware cursor. Needs a window.

const READ_WPS := 4.0   # 240 words a minute, a quick adult reader

var _args: PackedStringArray
var _dir := ""
var _t := 0.0
var _frame := 0
var _marks: Array = []
var _ptr := Vector2(480, 300)
var _ptr_down := false
var _cursor: Ptr = null
var _clicks := 0
var _dismiss_clicks := 0
var _live := true
var _last_step := ""
var _last_hint := ""


class Ptr extends Control:
	var at := Vector2.ZERO
	var hide_it := false

	func _draw() -> void:
		if hide_it:
			return
		var rows := [
			"X", "XX", "XWX", "XWWX", "XWWWX", "XWWWWX", "XWWWWWX", "XWWWWWWX",
			"XWWWWXXXX", "XWXWWX", "XX XWWX", "X   XWWX", "     XX",
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


func _process(delta: float) -> void:
	if not _live:
		return
	_t += delta
	_frame += 1
	if _cursor != null:
		_cursor.at = _ptr
		var sc := Router.current as SectorScreen
		_cursor.hide_it = sc != null and is_instance_valid(sc) and sc._cursor_off
		_cursor.queue_redraw()
	# the goal line's step and the hint card, as they change
	var g: GoalLine = Router.hud.goal if Router.hud != null else null
	var st := g._step.text if g != null and g.visible and g._step.visible else ""
	if st != _last_step:
		_last_step = st
		if st != "":
			_mark("goal_step", {text = st})
	var h := ""
	if Hints.card != null and is_instance_valid(Hints.card):
		h = String(Hints.card.id)
	if h != _last_hint:
		if h != "":
			_mark("hint_" + h, {text = " / ".join(PackedStringArray(Hints.lines(StringName(h))))})
		elif _last_hint != "":
			_mark("hint_gone_" + _last_hint)
		_last_hint = h


func _mark(name: String, extra: Dictionary = {}) -> void:
	var d := {name = name, frame = _frame, t = snappedf(_t, 0.01),
		clicks = _clicks, dismiss = _dismiss_clicks}
	d.merge(extra)
	_marks.append(d)
	print("mark %s %d %.2f %s" % [name, _frame, _t, JSON.stringify(extra) if not extra.is_empty() else ""])


func _wait(s: float) -> void:
	var until := _t + s
	while _t < until:
		await get_tree().process_frame


func _read(words: int) -> void:
	await _wait(1.0 + float(words) / READ_WPS)


func _until(cond: Callable, max_s: float = 30.0) -> bool:
	var until := _t + max_s
	while _t < until:
		if cond.call():
			return true
		await get_tree().process_frame
	return false


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
		# a real click reaches the root too, where the hints listen
		if down:
			Hints.click(mb)
		_ptr_down = down
	else:
		var mm := InputEventMouseMotion.new()
		mm.position = at
		mm.global_position = at
		mm.relative = at - _ptr
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT if _ptr_down else 0
		vp.push_input(mm)
	_ptr = at


func _glide(to: Vector2, s: float = 0.45) -> void:
	var from := _ptr
	var n := maxi(1, int(s * 30.0))
	for i in n:
		var u := float(i + 1) / float(n)
		var e := u * u * (3.0 - 2.0 * u)
		_push(from.lerp(to, e).round(), false, false)
		await get_tree().process_frame


## A click on a control, as a hand does it. `dismiss`: the click only puts
## something away (counted apart).
func _click(c: Control, why: String, dismiss: bool = false) -> void:
	if c == null or not is_instance_valid(c):
		_mark("click_missing", {why = why})
		return
	var at := c.get_global_rect().get_center().round()
	await _glide(at)
	c.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await _wait(0.2)
	var fired := [false]
	var b := c as Button
	var on_press := func() -> void: fired[0] = true
	if b != null:
		b.pressed.connect(on_press)
	_clicks += 1
	if dismiss:
		_dismiss_clicks += 1
	_mark("click", {why = why, what = b.text if b != null else c.get_class(), dismiss = dismiss})
	_push(at, true, true)
	await _wait(0.1)
	_push(at, false, true)
	if b != null and is_instance_valid(b):
		b.notification(Control.NOTIFICATION_MOUSE_EXIT)
		if not fired[0] and not b.disabled and b.is_visible_in_tree():
			b.pressed.emit()
		if b.pressed.is_connected(on_press):
			b.pressed.disconnect(on_press)
	await _wait(0.1)


## A click on a point (the chart, a ship, empty space).
func _click_at(at: Vector2, why: String, dismiss: bool = false) -> void:
	await _glide(at.round())
	await _wait(0.2)
	_clicks += 1
	if dismiss:
		_dismiss_clicks += 1
	_mark("click", {why = why, at = [at.x, at.y], dismiss = dismiss})
	_push(at.round(), true, true)
	await _wait(0.1)
	_push(at.round(), false, true)
	await _wait(0.1)


## A hint up: read it, then the next click the player was going to make
## dismisses it. Nothing to do here but read: the click is the next action's.
func _read_hint() -> void:
	if Hints.card != null and is_instance_valid(Hints.card):
		var words := 0
		for l in Hints.lines(Hints.card.id):
			words += String(l).split(" ").size()
		await _read(words)


func _find_button(root: Node, text: String) -> Button:
	if root == null:
		return null
	if root is Button and (root as Button).text == text and (root as Button).is_visible_in_tree():
		return root
	for c in root.get_children():
		var b := _find_button(c, text)
		if b != null:
			return b
	return null


func _overlay() -> void:
	var vp := GameShell.input_target(get_tree())
	var layer := CanvasLayer.new()
	layer.layer = 127
	vp.add_child(layer)
	_cursor = Ptr.new()
	_cursor.size = Vector2(960, 540)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_cursor)


func _screen_name() -> String:
	var cur := Router.current
	return cur.get_script().get_global_name() if cur != null else "none"


func _finish(code: int = 0) -> void:
	_mark("end", {screen = _screen_name()})
	_live = false
	if _dir != "":
		var fa := FileAccess.open(_dir + "/marks.json", FileAccess.WRITE)
		fa.store_string(JSON.stringify(_marks, "  "))
		fa.close()
	print("firstrunfilm: %d marks, %d clicks (%d only dismiss)" % [_marks.size(), _clicks, _dismiss_clicks])
	get_tree().quit(code)


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	_dir = _arg("out")
	if _dir != "":
		DirAccess.make_dir_recursive_absolute(_dir)
	Router.animate_in_harness = true
	Audio.taping = true
	# a fresh player in the harness's own settings file: the note, the intro and
	# every hint unseen
	Hints.forced = true
	Hints.reset()
	WelcomePopup.mark_seen(false)
	# a first launch: no suspend save, nothing on the flight record (the
	# harness's own scratch files)
	SaveGame.clear()
	RunHistory.clear()
	Rng.forced = int(_arg("seed", "4242"))
	_overlay()
	Sig.screen_changed.connect(func() -> void: _mark("screen", {screen = _screen_name()}))
	_mark("title")
	await _flow()
	_finish()


func _flow() -> void:
	# ---- 1. the title, Jon's note over it
	await _until(func() -> bool: return Router.current != null and Router.current.find_child("WelcomePopup", true, false) != null, 10.0)
	var wp := Router.current.find_child("WelcomePopup", true, false) as WelcomePopup
	_mark("welcome_note", {words = AlphaNotes.ALPHA_WELCOME.split(" ").size()})
	# a new player skims Jon's letter: 15 s (a full read at 240 wpm is ~40 s)
	await _wait(float(_arg("note_s", "15")))
	if wp != null:
		await _click(wp.button, "close the welcome note", true)
	await _wait(1.2)
	# ---- 2. NEW RUN, then the hull pick (a fresh profile has no seed panel;
	# a profile with a save or a flight record does, and it is read and passed)
	var nr := _find_button(Router.current, "NEW RUN")
	_mark("new_game")
	var t_new := _t
	await _click(nr, "NEW RUN")
	await _wait(0.6)
	if not (Router.current is ChassisSelect):
		_mark("seed_popup", {text = "LAUNCH A RUN / Leave the seed empty for a new, random galaxy."})
		await _read(13)
		await _click(_find_button(Router.current, "LAUNCH"), "LAUNCH (seed popup)", true)
	await _until(func() -> bool: return Router.current is ChassisSelect, 10.0)
	_mark("chassis_select")
	# looking the hull over, as a new player does
	await _wait(float(_arg("chassis_s", "8")))
	await _click(_find_button(Router.current, "LAUNCH"), "LAUNCH (hull pick)")
	_mark("launched")
	# ---- 3. the arrival; no tour: the controls are yours when the ship stops
	await _until(func() -> bool:
		var s := Router.current as SectorScreen
		return s != null and s.cutaway_ready(), 30.0)
	_mark("first_control", {screen = _screen_name(), since_new_game = snappedf(_t - t_new, 0.01)})
	# the goal line says what to do: read it, then open STARCHART as it says
	await _wait(0.5)
	_mark("goal_read", {text = "GOAL: REACH THE CORE / " + _last_step})
	await _read(4 + _last_step.split(" ").size())
	await _read_hint()
	await _click(Router.hud._tab_chart, "STARCHART (the goal line's step)")
	await _until(func() -> bool: return Router.current is StarchartScreen and not ZoomLadder.busy(), 10.0)
	# ---- 4. the chart: its hint, then pick a star in range, JUMP
	await _until(func() -> bool: return Hints.card != null or Hints.seen(&"chart"), 3.0)
	await _read_hint()
	await _wait(1.0)
	var chart := Router.current as StarchartScreen
	var pick: MapGen.MapNode = null
	var best := INF
	var here := Run.node_at()
	for raw in Run.in_range():
		var n: MapGen.MapNode = raw
		if n == here or not Run.can_jump_to(n) or n.type != MapGen.NodeType.SYSTEM:
			continue
		var dd: float = (n.gal - here.gal).length()
		# a system with a fight on offer, if one is in range (a new player
		# picks some star; this one has the film's first fight in it)
		OptionTable.ensure(n)
		var has_fight := false
		for oid in n.options:
			var oo := OptionTable.by_id(oid)
			if EncounterDrawer.lead_tag(oo) == &"fight":
				has_fight = true
		if not has_fight:
			dd += 1000.0
		if dd < best:
			best = dd
			pick = n
	if chart == null or pick == null:
		_mark("no_chart_pick", {screen = _screen_name()})
		return
	var mc: Control = chart._chart
	var at: Vector2 = mc.get_global_transform() * mc._screen_pos(pick)
	await _click_at(at, "pick a star")
	await _wait(0.4)
	if chart._selected != pick.index:
		chart._on_node_picked(pick.index)
		_mark("pick_fallback")
	_mark("star_picked", {name = MapGen.star_name(pick), danger = pick.danger})
	await _wait(2.5)
	await _click(chart._jump, "JUMP")
	_mark("first_jump")
	# the departure, the drive, the arrival
	await _until(func() -> bool:
		return Run.jumps >= 1 and (_in_fight() or Router.current is SystemMapScreen), 40.0)
	_mark("arrived", {screen = _screen_name(), fighting = _in_fight()})
	await _wait(2.5)
	# ---- 5. events until a fight
	var events := 0
	while not _in_fight() and events < 4:
		var sc := Router.current as SectorScreen
		if sc != null:
			await _wait(1.5)
			var scan := _find_button(sc, "SCAN SECTOR")
			_mark("drawer_line")
			await _read(5)
			await _click(scan, "SCAN SECTOR")
			await _until(func() -> bool: return Router.current is SystemMapScreen, 10.0)
			await _wait(1.0)
		var map := Router.current as SystemMapScreen
		_mark("sector_map")
		# the map's hint, then read the event list (a sentence each)
		await _until(func() -> bool: return Hints.card != null or Hints.seen(&"events"), 3.0)
		await _read_hint()
		await _wait(4.0)
		var go := _first_go(map)
		if go == null:
			# the list page: click the first open event's card, its page has GO
			var pick_card: Control = null
			for c in map.find_children("*", "", true, false):
				if c is PanelContainer and c.has_method("set_doomed") and not c.get("doomed") and not c.get("finished") 						and (c.get("press") as Callable).is_valid() and (c as Control).is_visible_in_tree():
					var fight: bool = c.get("stripe_col") == UITheme.LEAVE
					if pick_card == null or fight:
						pick_card = c
					if fight:
						break
			await _click(pick_card, "event card")
			await _until(func() -> bool: return _first_go(map) != null, 5.0)
			await _wait(1.0)
			_mark("event_page")
			await _read(25)
			await _read_hint()
			go = _first_go(map)
		if go == null:
			_mark("no_go")
			return
		await _click(go, "GO")
		events += 1
		_mark("event_go", {n = events})
		# the flight and the zoom down to LOCAL, the band up, the text arriving
		await _until(func() -> bool:
			var s := Router.current as SectorScreen
			return s != null and s._events != null and is_instance_valid(s._events) and s._events.page == &"event" \
				and s._events.text != null and s._events.text.done, 40.0)
		sc = Router.current as SectorScreen
		var d := sc._events
		var o := OptionTable.by_id(d.node.options[d.opt])
		var body := String(o.get("body", ""))
		_mark("event_text", {title = String(o.get("title", "")), words = body.split(" ").size()})
		await _read(body.split(" ").size())
		await _until(func() -> bool: return Hints.card != null or Hints.seen(&"drawer"), 2.0)
		await _read_hint()
		var choices: Array = o.get("choices", [])
		var j := 0
		for k in choices.size():
			if bool((choices[k] as Dictionary).get("fight", false)) and OptionResolve.affordable(choices[k]):
				j = k
				break
		var card := d.find_child("Choice%d" % j, true, false) as Control
		await _click(card, "choice %d" % j)
		await _wait(0.5)
		if is_instance_valid(d) and d.page == &"event":
			d.choose(j)
			_mark("choice_fallback")
		# (through a weak reference: the band is freed when the fight takes the
		# screen, and a lambda holding it then reads a freed capture)
		var dw: WeakRef = weakref(d)
		await _until(func() -> bool:
			var dd = dw.get_ref()
			return dd == null or dd.page == &"result" or _in_fight(), 10.0)
		if is_instance_valid(d) and d.page == &"result":
			await _until(func() -> bool:
				var dd = dw.get_ref()
				return dd == null or dd.text == null or dd.text.done, 20.0)
			_mark("event_result", {fight = d.find_child("TheyAreFiring", true, false) != null})
			await _read(25)
			var fire := d.find_child("TheyAreFiring", true, false) as Button
			if fire != null:
				await _click(fire, "THEY ARE FIRING")
				await _until(func() -> bool: return _in_fight(), 15.0)
				break
			var cont := d.find_child("Continue", true, false) as Button
			await _click(cont, "CONTINUE", true)
			await _wait(1.0)
		await _until(func() -> bool: return Router.current is SectorScreen, 10.0)
	if not _in_fight():
		_mark("no_fight")
		return
	await _fight()
	await _after_fight()


func _in_fight() -> bool:
	var s := Router.current as SectorScreen
	return s != null and s.fighting()


func _first_go(map: SystemMapScreen) -> Button:
	for c in map.find_children("Go", "Button", true, false):
		var b := c as Button
		if b != null and b.is_visible_in_tree() and not b.disabled:
			return b
	return null


func _fight() -> void:
	var sc := Router.current as SectorScreen
	var cb: Combat = Router.combat
	var names: Array = []
	for e in cb.enemies:
		names.append((e as Combat.EnemyState).template.name)
	_mark("fight_start", {foes = names, energy = cb.energy, hand = cb.hand.size(), heat = Run.heat, cap = Run.heat_cap()})
	var first_card := true
	var heat_seen := false
	var block_seen := false
	var pol := Policy.new()
	var turns := 0
	Sig.turn_started.connect(func(t: int) -> void: _mark("turn", {turn = t, energy = cb.energy, heat = Run.heat, hp = Run.hp}))
	Sig.overheated.connect(func(b: int) -> void: _mark("overheated", {burn = b}))
	while not cb.finished and turns < 12:
		# the hand settled: the band up, END TURN live
		await _until(func() -> bool: return cb.finished or (not sc._hold and not sc._opening and sc._end_button != null \
			and sc._end_button.is_visible_in_tree() and not sc._end_button.disabled), 30.0)
		if cb.finished:
			break
		if first_card:
			var it: IntentData = (cb.enemies[0] as Combat.EnemyState).intent
			_mark("hand_up", {intent = it.name if it != null else ""})
			# a new player reads the board: the intent, the cards, the gauges
			await _wait(4.0)
			await _until(func() -> bool: return Hints.card != null or Hints.seen(&"hand"), 2.0)
			await _read_hint()
		else:
			# a beat to look, and any hint that comes up in it is read
			await _wait(0.9)
			await _read_hint()
		var pick := pol.best_card(cb)
		if pick < 0:
			await _wait(0.3)
			await _read_hint()
			await _click(sc._end_button, "END TURN")
			turns += 1
			await _wait(1.5)
			continue
		var card: CardData = cb.hand[pick]
		var h0 := Run.heat
		await _play(sc, cb, pick)
		if first_card:
			first_card = false
			_mark("first_card", {card = card.name})
		if not heat_seen and Run.heat > h0:
			heat_seen = true
			_mark("first_heat", {heat = Run.heat, cap = Run.heat_cap()})
		if not block_seen and cb.block > 0:
			block_seen = true
			_mark("first_block", {block = cb.block})
		await _wait(0.8)
	_mark("fight_done", {result = String(cb.result), hp = Run.hp, heat = Run.heat})


func _view_of(sc: SectorScreen, card: CardData) -> CardView:
	for v in sc._hand._views:
		if v != null and is_instance_valid(v) and v.card == card:
			return v
	return null


func _play(sc: SectorScreen, cb: Combat, pick: int) -> void:
	var card: CardData = cb.hand[pick]
	var v := _view_of(sc, card)
	if v == null:
		cb.play(pick, 0)
		return
	var aim_enemy := card.damage > 0 or card.damage_equals_heat or card.evoke > 0
	var target := Vector2.ZERO
	if aim_enemy:
		var tgt := 0
		var lo := 1 << 30
		for i in cb.enemies.size():
			var e: Combat.EnemyState = cb.enemies[i]
			if e.hp > 0 and e.hp < lo:
				lo = e.hp
				tgt = i
		target = sc._view.slot(tgt).holder_rect().get_center()
	else:
		target = sc._view.ship_view().get_global_rect().get_center()
	var r := v.get_global_rect()
	var on := Vector2(r.get_center().x, r.position.y + r.size.y * 0.55).round()
	await _glide(on, 0.5)
	v.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await _wait(0.6)
	if not is_instance_valid(v):
		return
	r = v.get_global_rect()
	on = Vector2(r.get_center().x, r.position.y + r.size.y * 0.55).round()
	_clicks += 1
	_push(on, true, true)
	await _wait(0.1)
	await _glide(Vector2(on.x, sc._hand.get_global_rect().position.y - 30.0), 0.27)
	await _glide(target.round(), 0.45)
	await _wait(0.6)
	_push(_ptr, false, true)
	await _wait(0.1)
	await _glide(Vector2(_ptr.x, 470), 0.33)


func _after_fight() -> void:
	# the kill, the wreck, LOCAL easing in
	await _until(func() -> bool: return Router.combat == null and Router.current is SectorScreen, 30.0)
	var sc := Router.current as SectorScreen
	await _wait(2.0)
	var cont := _find_button(sc, "CONTINUE")
	if cont != null:
		_mark("victory_panel")
		await _read(20)
		await _click(cont, "CONTINUE (victory)", true)
	_mark("local_after_fight")
	await _until(func() -> bool: return Hints.card != null, 6.0)
	await _read_hint()
	# the wreck: click it
	var art: EnemyArt = sc._view.enemy_view(0)
	if art != null and art.is_visible_in_tree():
		await _click_at(art.get_global_rect().get_center(), "the wreck")
		await _until(func() -> bool: return sc._transfer != null, 4.0)
		if sc._transfer != null:
			_mark("wreck_open", {title = sc._transfer._title.text})
			await _wait(1.5)
			await _until(func() -> bool: return Hints.card != null or Hints.seen(&"salvage"), 3.0)
			await _read_hint()
			await _drag_loot(sc._transfer)
			await _wait(1.5)
			if sc._transfer != null:
				await _click(_find_button(sc._transfer, "DONE"), "DONE (wreck)")
	await _wait(1.0)
	# whatever hint comes next (SECTOR LOOT, your ship)
	for k in 3:
		if not await _until(func() -> bool: return Hints.card != null, 4.0):
			break
		await _read_hint()
		await _click_at(Vector2(300, 120), "empty space (dismiss a hint)", true)
	await _wait(3.0)


func _drag_loot(tv: TransferView) -> void:
	# a player drags first; when the drag will not take, they double-click
	# (ItemIcon: "the one everybody tries first"). The bot's pushed drag does
	# not start Godot's drag, so the film shows the double-click.
	var taken := 0
	for k in 3:
		var icons := tv._loose.find_children("*", "ItemIcon", true, false)
		if icons.is_empty():
			break
		var it := icons[0] as Control
		var at := it.get_global_rect().get_center().round()
		await _glide(at, 0.5)
		await _wait(0.3)
		_clicks += 1
		_mark("take_part", {how = "double-click"})
		var vp := GameShell.input_target(get_tree())
		for dbl in [false, true]:
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTON_LEFT
			mb.pressed = true
			mb.double_click = dbl
			mb.position = at
			mb.global_position = at
			mb.button_mask = MOUSE_BUTTON_MASK_LEFT
			vp.push_input(mb)
			await get_tree().process_frame
			var up := mb.duplicate() as InputEventMouseButton
			up.pressed = false
			up.double_click = false
			up.button_mask = 0
			vp.push_input(up)
			await _wait(0.08)
		await _wait(0.8)
		taken += 1
	if taken == 0:
		_mark("wreck_no_parts")
