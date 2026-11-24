extends Node

## The front door's banner click kept cheap without changing a pixel: hulls baked
## ahead on a worker as the main thread bakes them, a room built only when the banner
## changes rooms. Counts work, never times it (`docs/tests.md`).
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


## A room is built when the banner changes rooms and never on a pick, and every set,
## open or locked, stands its three berths on two posts each.
func _maps(cs: ChassisSelect) -> void:
	var y := cs._yard
	var builds0 := ShipRoom.builds
	var changes := 0
	var last := y.room.id if y.room != null else &""
	var was_dev := DevMode.enabled
	for pass_dev: bool in [true, false]:
		DevMode.enabled = pass_dev and DevMode.available
		for i in DB.STARTABLE.size():
			var m: StringName = DB.STARTABLE[i]
			var open := Unlocks.unlocked(m)
			y.show_set(m, open, 0)
			if ShipRoom.id_for(m, open) != last:
				changes += 1
				last = ShipRoom.id_for(m, open)
			var posts := 0
			for s: YardStandSet in y.sets.values():
				posts += s.post_x.size()
			h._ok("%s %s: in the %s room, %d posts" % [m, "hulls" if open else "tarps", y.room.id, posts],
				y.room.id == ShipRoom.id_for(m, open) and posts == 6)
	DevMode.enabled = was_dev
	h._ok("a room was built once a room change (%d for %d)" % [ShipRoom.builds - builds0, changes],
		ShipRoom.builds - builds0 == changes)
	var before := ShipRoom.builds
	y.set_picked(int(HullData.Weight.MEDIUM))
	y.set_picked(-1)
	h._ok("a pick builds no room", ShipRoom.builds == before)


func _finish() -> void:
	HullGrade.finish_ahead()
	DevMode.enabled = _dev_was
	h.verdict("yardperftest")
	_tree.quit(h.code())
