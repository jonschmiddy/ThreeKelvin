extends Node

## The front door's banner click kept cheap without changing a pixel: hulls baked
## ahead on a worker as the main thread bakes them, the ship map byte for byte the
## per-pixel one, the pools baked once. Counts work, never times it (`docs/tests.md`).
## Why: docs/why/ChassisSelect.md#hulls-baked-ahead

var _tree: SceneTree
var h := Harness.new()
var _dev_was := false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tree = get_tree()
	await Harness.frames(_tree, 2)
	_dev_was = DevMode.enabled
	# every banner open where the binary allows it, so every manufacturer's hulls are on the stands
	DevMode.enabled = DevMode.available
	Router.new_run(4242)
	await Harness.frames(_tree, 4)
	var cs := Router.current as ChassisSelect
	if not h._ok("NEW RUN opens the hull pick on the hall", cs != null and cs._yard.ready_hall):
		return _finish()
	_same_bakes()
	await _ahead(cs)
	_maps(cs)
	_finish()


## A worker's bake is the main thread's, byte for byte, with three manufacturers baking at once.
func _same_bakes() -> void:
	var hulls: Array[HullData] = []
	for m: StringName in [&"solari", &"redline", &"calyx", &"korvan"]:
		hulls.append(DB.at_tier(DB.hull_for(m, HullData.Weight.HEAVY), 1))
	# (a seed of its own each: Redline's and Calyx's heavies wear Korvan's picture)
	var seed_of := func(x: HullData) -> int: return 9100 + absi(hash(x.manufacturer)) % 1000
	HullGrade.bake_ahead(hulls, seed_of)
	for x in hulls:
		var key := HullGrade.key_for(x)
		if key == "":
			continue
		var ck := "%s|%d|0|%d" % [key, x.tier, seed_of.call(x)]
		if not h._ok("%s's bake went to a worker" % key, HullGrade._ahead.has(ck)):
			continue
		var got := HullGrade._collect(ck)
		var want := HullGrade.bake_mix(HullGrade._full(x), clampi(x.tier, 0, 3), HullGrade.SHIPPED, seed_of.call(x), key)
		h._ok("%s baked on a worker is the main thread's picture" % key,
			got != null and got.get_size() == want.get_size() and got.get_data() == want.get_data())


## Every open banner's hulls are baked ahead, and a banner's click bakes none on the main thread.
func _ahead(cs: ChassisSelect) -> void:
	var t0 := Time.get_ticks_msec()
	while not (cs._to_bake.is_empty() and HullGrade.ahead_idle()) and Time.get_ticks_msec() - t0 < 120000:
		await _tree.process_frame
	print("  yardperf: %d hulls baked ahead in %.1f s" % [DB.STARTABLE.size() * 3, (Time.get_ticks_msec() - t0) / 1000.0])
	var missing: Array[String] = []
	for m: StringName in DB.STARTABLE:
		if not Unlocks.unlocked(m):
			continue
		for w: HullData.Weight in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
			var x := DB.at_tier(DB.hull_for(m, w), cs._tier)
			var key := HullGrade.key_for(x)
			var ck := "%s|%d|0|%d" % [key, x.tier, ChassisSelect._bake_seed(x)]
			if key != "" and not HullGrade._tex.has(ck) and not HullGrade._ahead.has(ck):
				missing.append(ck)
	h._ok("every open banner's hulls are baked or baking before their click (missing %s)" % [missing], missing.is_empty())
	HullGrade.finish_ahead()
	var bakes_before := HullGrade._tex.size()
	for i in DB.STARTABLE.size():
		var u := Time.get_ticks_usec()
		cs._select(i)
		print("  yardperf: banner %s clicked in %.1f ms" % [DB.STARTABLE[i], (Time.get_ticks_usec() - u) / 1000.0])
	h._ok("a banner's click baked nothing new (%d pictures, then %d)" % [bakes_before, HullGrade._tex.size()],
		HullGrade._tex.size() == bakes_before)
	cs._select(0)


## The ship map in bytes is the per-pixel one, set by set, open and locked; the pools baked once.
func _maps(cs: ChassisSelect) -> void:
	var y := cs._yard
	# (a bake of the pools sets this back: headless, `_bake_bay` finishes at once)
	y.scene._bay_ready = false
	var was_dev := DevMode.enabled
	for pass_dev: bool in [true, false]:
		DevMode.enabled = pass_dev and DevMode.available
		for i in DB.STARTABLE.size():
			var m: StringName = DB.STARTABLE[i]
			var open := Unlocks.unlocked(m)
			y.show_set(m, open, 0)
			var got := y.ship_map()
			var want := _old_map(y)
			var lit := 0
			for k in range(0, got.size(), 4):
				lit += 1 if got[k] == 255 else 0
			h._ok("%s %s: the ship map is the per-pixel one (%d hull pixels)" % [m, "hulls" if open else "tarps", lit],
				got == want and lit > 0)
	DevMode.enabled = was_dev
	h._ok("the floor pools were baked once, not once a click", y._bay_baked and not y.scene._bay_ready)
	y.scene._bay_ready = true


## The map as `YardFront._rebake` made it before Nov 12, pixel by pixel.
func _old_map(y: YardFront) -> PackedByteArray:
	var img := Image.create(YardFront.W, YardFront.HALL_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for w: HullData.Weight in y.sets:
		var s: YardStandSet = y.sets[w]
		if s._stand_img != null:
			for sx in s._stand_x:
				_stamp(img, s._stand_img, Rect2i(Vector2i.ZERO, s._stand_img.get_size()), Vector2i(sx, s._stand_top), Color8(0, 255, 0, 255), false)
		if s._view != null:
			var c := s._view.canvas()
			_stamp(img, c, c.get_used_rect(), Vector2i(s._x0, s.thing.position.y), Color8(255, 0, 0, 255), true)
		elif s._tarp != null and s._tarp.image != null:
			_stamp(img, s._tarp.image, Rect2i(Vector2i.ZERO, s._tarp.image.get_size()), s.thing.position, Color8(255, 0, 0, 255), true)
	for x in YardFront.W:
		var top := -1
		var bot := -1
		for yy in YardFront.HALL_H:
			if img.get_pixel(x, yy).r8 == 255:
				if top < 0:
					top = yy
				bot = yy
		if top < 0 or bot - top < 6:
			continue
		for yy in range(top, bot + 1):
			var c := img.get_pixel(x, yy)
			if c.r8 != 255:
				continue
			var u := float(yy - top) / float(bot - top)
			var k := floorf(clampf((u - 0.5) / 0.5, 0.0, 1.0) * 3.0 + 0.5) / 3.0
			c.b8 = clampi(int(floorf((1.0 - 0.45 * k) * 255.0 + 0.5)), 1, 255)
			img.set_pixel(x, yy, c)
	return img.get_data()


static func _stamp(img: Image, src: Image, ink: Rect2i, at: Vector2i, col: Color, over: bool) -> void:
	for yy in ink.size.y:
		for x in ink.size.x:
			if src.get_pixel(ink.position.x + x, ink.position.y + yy).a8 < 128:
				continue
			var X := at.x + x
			var Y := at.y + yy
			if X < 0 or Y < 0 or X >= img.get_width() or Y >= img.get_height():
				continue
			if over or img.get_pixel(X, Y).r8 == 0:
				img.set_pixel(X, Y, col)


func _finish() -> void:
	HullGrade.finish_ahead()
	DevMode.enabled = _dev_was
	h.verdict("yardperftest")
	_tree.quit(h.code())
