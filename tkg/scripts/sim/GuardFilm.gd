extends Node

## Films one creature's block, brace or damage in the real SectorScreen via `Combat.damage_enemy`.
## `boxtest=1` checks the words' pixels are identical with the guard drawn and hidden.
## Why: docs/why/GuardFilm.md#guard-film

const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")

var _box := false
var _box_bad := 0
var _box_n := 0
var _box_seen := 0
var _shots := ""
var _next_shot := 0.0


func _ready() -> void:
	_run.call_deferred()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	var id := StringName(Harness.arg("id", "leviathan"))
	var def := Harness.arg("def", "block")
	var look := Harness.arg("look", "0")
	_box = Harness.arg("boxtest", "0") == "1"
	_shots = Harness.arg("shots", "")
	if _shots != "":
		DirAccess.make_dir_recursive_absolute(_shots)
	if look == "ship":
		FaunaGuard.enabled = false
	FaunaHitFx.force_kind = int(Harness.arg("kind", "-1"))
	Rng.forced = Harness.seed_arg(4242)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for n: MapGen.MapNode in Run.map:
		if n.type != MapGen.NodeType.STATION and n.type != MapGen.NodeType.START \
				and String(SkyWeatherS.sky_of_node(n)) == "calm":
			Run.at = n.index
			break
	SectorScreen._approached_at = Run.at
	Router.start_combat(DB.enemies[id], [], false, false)
	var cb: Combat = Router.combat
	var e: Combat.EnemyState = cb.enemies[0]
	e.hp = e.max_hp
	e.block = 0
	e.brace = 0
	Sig.enemy_changed.emit()
	var sc := Router.current as SectorScreen
	await _wait(float(Harness.arg("settle", "3.4")))
	var sl: EnemySlot = sc._view.slot(0)
	var L: HitLayers = sl.layers
	var k := float(get_window().size.x) / get_viewport().get_visible_rect().size.x
	var r := sl.holder_rect()
	for rr in [sl.intent_rect_global(), sl.readout_rect_global()]:
		if (rr as Rect2).size != Vector2.ZERO:
			r = r.merge(rr)
	r = r.grow(10.0)
	print("guardfilm: crop %d %d %d %d" % [int(r.position.x * k), int(r.position.y * k), int(r.size.x * k), int(r.size.y * k)])
	print("guardfilm: creature %s, %s" % [str(L.body != null), L.hits.get_class()])
	if L.body != null:
		print("guardfilm: body cut %.1f ms, fps %.0f" % [L.body.cut_ms, L.body.fps])
	print("guardfilm: start %d" % Engine.get_frames_drawn())
	var t0 := 0.0
	var plan: Array = []
	match def:
		"block":
			plan = [[0.0, &"block", 12], [2.0, &"hit", 5], [3.6, &"hit", 10], [6.1, &"end", 0]]
		"brace":
			plan = [[0.0, &"brace", 12], [1.7, &"hit", 4], [2.9, &"hit", 4], [4.1, &"hit", 6], [6.1, &"end", 0]]
		"guard":
			plan = [[0.0, &"brace", 12], [0.0, &"block", 10], [1.8, &"hit", 6], [3.2, &"hit", 8], [4.6, &"hit", 6],
				[5.8, &"hit", 6], [7.2, &"end", 0]]
		"damage":
			var each := int(ceil(float(e.max_hp) * 0.115))
			for i in 8:
				plan.append([0.4 + 0.8 * float(i), &"hit", each])
			plan.append([7.0, &"end", 0])
	var marks := []
	var now := 0.0
	var next_mark := 0.0
	var pi := 0
	var start_ms := GameClock.now()
	while pi < plan.size():
		now = GameClock.now() - start_ms
		if now >= next_mark:
			next_mark += 0.5
			marks.append([snappedf(now, 0.01), _changes(L)])
		var step: Array = plan[pi]
		if now >= float(step[0]):
			pi += 1
			match step[1]:
				&"block":
					e.block = int(step[2])
					Sig.enemy_changed.emit()
				&"brace":
					e.brace = int(step[2])
					Sig.enemy_changed.emit()
				&"hit":
					Run.hp = Run.max_hp()
					cb.damage_enemy(int(step[2]), 1, "film", e)
				&"end":
					break
		if _box and L != null:
			await _boxtest(sl, L)
		if _shots != "" and now >= _next_shot:
			_next_shot += 0.25
			var im := get_viewport().get_texture().get_image()
			var cr := Rect2i(Vector2i(r.position * float(im.get_width()) / get_viewport().get_visible_rect().size.x),
				Vector2i(r.size * float(im.get_width()) / get_viewport().get_visible_rect().size.x))
			im.get_region(cr.intersection(Rect2i(Vector2i.ZERO, im.get_size()))).save_png(_shots + "/s%03d.png" % int(round(now * 100.0)))
		await tree.process_frame
	marks.append([snappedf(GameClock.now() - start_ms, 0.01), _changes(L)])
	print("guardfilm: hull %d/%d block %d brace %d" % [e.hp, e.max_hp, e.block, e.brace])
	print("guardfilm: changes %s" % JSON.stringify(marks))
	if _box:
		print("guardfilm: boxtest %d samples, %d with guard pixels on screen, %d on the words" % [_box_n, _box_seen, _box_bad])
	print("guardfilm: done")
	tree.quit()


func _changes(L: HitLayers) -> Array:
	if L == null:
		return []
	return [int(L.shield.get("changes") if L.shield.get("changes") != null else -1),
		int(L.brace.get("changes") if L.brace.get("changes") != null else -1),
		int(L.hits.get("changes") if L.hits.get("changes") != null else -1)]


var _last_box := -1.0


## The words' pixels with the guard drawn and hidden, the same moment: any
## difference is the guard on them.
func _boxtest(sl: EnemySlot, L: HitLayers) -> void:
	var now := GameClock.now()
	if now - _last_box < 0.1:
		return
	_last_box = now
	var k := float(get_window().size.x) / get_viewport().get_visible_rect().size.x
	RenderingServer.force_draw(false, 0.0)
	var on := get_viewport().get_texture().get_image()
	L.visible = false
	RenderingServer.force_draw(false, 0.0)
	var off := get_viewport().get_texture().get_image()
	L.visible = true
	_box_n += 1
	# anywhere (the guard is on screen at all)
	var any := 0
	var hr := sl.holder_rect().grow(30.0)
	for y in range(int(hr.position.y * k), int(hr.end.y * k), 2):
		for x in range(int(hr.position.x * k), int(hr.end.x * k), 2):
			if x < 0 or y < 0 or x >= on.get_width() or y >= on.get_height():
				continue
			if on.get_pixel(x, y) != off.get_pixel(x, y):
				any += 1
	if any > 0:
		_box_seen += 1
	var bad := 0
	for rr in [sl.intent_rect_global(), sl.readout_rect_global()]:
		var r: Rect2 = rr
		for y in range(int(r.position.y * k), int(ceil(r.end.y * k))):
			for x in range(int(r.position.x * k), int(ceil(r.end.x * k))):
				if x < 0 or y < 0 or x >= on.get_width() or y >= on.get_height():
					continue
				if on.get_pixel(x, y) != off.get_pixel(x, y):
					bad += 1
	if bad > 0:
		_box_bad += 1
		print("guardfilm: boxtest overlap %d px at %.2f" % [bad, now])
