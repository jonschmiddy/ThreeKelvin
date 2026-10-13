extends Node

## THE BOBS RUN ON GAME TIME, NOT THE WALL'S (Jon, of the full fight films,
## Oct 13: "the hovering animation is REALLY fast for some reason").
##   godot --headless --path . -- sheet=GameClockTest
## The movie writer steps the game 1/60 s a frame however long a frame takes to
## write, so anything on `Time.get_ticks_msec()` raced through a film (the
## cutter's bob: 0.375 s a cycle against 4.76) and ignored the hit-stop's slow
## motion. Through the real SectorScreen, a pack of three, and your ship:
##   a frozen frame: `Engine.time_scale` 0 and one frame held 2.6 s on the wall
##     (over half of every bob's cycle): no bob moves;
##   fast time: `time_scale` 20 for 0.4 s on the wall (8 s of game time, more
##     than a cycle): every bob goes the whole way, top and bottom;
##   a slot made later, at the first slot's place in the pack, bobs in step
##     with it on the same frame (one clock for the pack, phases kept);
##   `ShipView.shot_clock` still drives your ship's bob, for the harnesses.

var h := Harness.new()
var _tree: SceneTree


func _ready() -> void:
	_tree = get_tree()
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


## Each bob's offset off its rest, now: the slots' art, then your ship.
func _offsets(slots: Array, ship: ShipView) -> Array:
	var out := []
	for s: EnemySlot in slots:
		out.append(roundi(s.art.position.y - s._art_base.y))
	out.append(ship._bob_off if ship != null else 0)
	return out


func _run() -> void:
	await _frames(2)
	h.seed_run(4242)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var idx := -1
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.SYSTEM and not n.cleared and not Router.no_fights_at(n):
			idx = n.index
			break
	Run.at = idx
	Run.map[idx].visited = true
	SectorScreen._approached_at = idx
	Router.show_local()
	await _frames(3)
	Router.start_combat(DB.enemies[&"cutter"], [DB.enemies[&"lancer"], DB.enemies[&"cutter"]], false, false)
	# past the fly-in, whatever it is headless
	await _frames(30)
	var t_in := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_in < 800:
		await _tree.process_frame
	var sc := Router.current as SectorScreen
	var cb: Combat = Router.combat
	if not _ok("a fight of three on the real screen", sc != null and cb != null and cb.enemies.size() == 3):
		_end()
		return
	var slots: Array = []
	for n2 in sc.find_children("*", "", true, false):
		if n2 is EnemySlot and (n2 as EnemySlot).is_visible_in_tree():
			slots.append(n2)
	slots.sort_custom(func(a: EnemySlot, b: EnemySlot) -> bool: return a.index < b.index)
	var ship: ShipView = h.first(sc, func(n3: Node) -> bool:
		return n3 is ShipView and (n3 as ShipView)._bob_amp > 0 and (n3 as ShipView).is_visible_in_tree()) as ShipView
	if not _ok("three enemy slots and your ship bobbing (%d slots)" % slots.size(),
			slots.size() == 3 and ship != null):
		_end()
		return

	# A FROZEN FRAME. The wall moves 2.6 s -- 0.55 of the slots' cycle, 0.78 of
	# your ship's -- and the game none.
	Engine.time_scale = 0.0
	await _frames(3)
	var before := _offsets(slots, ship)
	OS.delay_msec(2600)
	await _frames(3)
	var after := _offsets(slots, ship)
	Engine.time_scale = 1.0
	_ok("time stopped, 2.6 s on the wall: no bob moved (%s -> %s)" % [str(before), str(after)],
		before == after)

	# FAST TIME: 0.4 s on the wall is 8 s of game time, past a whole cycle.
	var lo := []
	var hi := []
	for i in slots.size() + 1:
		lo.append(99)
		hi.append(-99)
	Engine.time_scale = 20.0
	var t_fast := Time.get_ticks_msec()
	var frames := 0
	while Time.get_ticks_msec() - t_fast < 400:
		await _tree.process_frame
		frames += 1
		var o := _offsets(slots, ship)
		for i2 in o.size():
			lo[i2] = mini(lo[i2], o[i2])
			hi[i2] = maxi(hi[i2], o[i2])
	Engine.time_scale = 1.0
	var full := true
	for i3 in lo.size():
		var amp := int(EnemySlot.BOB_AMP) if i3 < slots.size() else ship._bob_amp
		full = full and lo[i3] == -amp and hi[i3] == amp
	_ok("time at 20x, 0.4 s on the wall over %d frames: every bob went top to bottom (low %s, high %s)"
		% [frames, str(lo), str(hi)], full)

	# A SLOT MADE LATER, in the first one's place: in step on the same frame.
	var late := EnemySlot.new()
	late.size = Vector2(160, 160)
	add_child(late)
	late.bind(0, cb.enemies[0], false)
	var agree := 0
	var seen := 0
	for k in 40:
		await _tree.process_frame
		seen += 1
		var a0 := roundi((slots[0] as EnemySlot).art.position.y - (slots[0] as EnemySlot)._art_base.y)
		var b0 := roundi(late.art.position.y - late._art_base.y)
		if a0 == b0:
			agree += 1
		# a long frame between, so the clock has moved on
		OS.delay_msec(30)
	_ok("a slot made later bobs in step with the first (%d of %d frames)" % [agree, seen], agree == seen)
	late.queue_free()

	# THE HARNESSES' HOOK: `shot_clock` still drives your ship.
	var q := 1.0 / (4.0 * ship._bob_hz)
	ShipView.shot_clock = q
	await _frames(2)
	var top := ship._bob_off
	ShipView.shot_clock = 3.0 * q
	await _frames(2)
	var bottom := ship._bob_off
	ShipView.shot_clock = -1.0
	_ok("shot_clock drives your ship's bob (%d at a quarter cycle, %d at three)" % [top, bottom],
		top == ship._bob_amp and bottom == -ship._bob_amp)
	_end()


func _end() -> void:
	Engine.time_scale = 1.0
	h.verdict("gameclocktest")
	_tree.quit(h.code())
