extends Node

## Regression for Jon's 0.4.1 save (Oct 23): pad items must stay visible and UNDOCK must work.
## Why: docs/why/SwapTest.md#hull-swap-softlock

const FIXTURE := "res://tools/fixtures/swap_softlock_0.4.1.save"

var h := Harness.new()
var _tree: SceneTree


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tree = get_tree()
	await Harness.frames(_tree, 2)
	print("-- Jon's save")
	await _jons_save()
	print("-- a hull bought at the yard")
	await _yard_swap()
	print("-- a hull found in space")
	await _found_swap()
	h.verdict("swaptest")
	_tree.quit(h.code())


# ------------------------------------------------------------------- helpers

## A real key, through Main's own handlers.
func _key(code: Key) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.physical_keycode = code
	k.pressed = true
	Input.parse_input_event(k)
	await Harness.frames(_tree, 1)
	var u := InputEventKey.new()
	u.keycode = code
	u.physical_keycode = code
	u.pressed = false
	Input.parse_input_event(u)
	await Harness.frames(_tree, 3)


func _transfer() -> TransferScreen:
	var t := Harness.node_with_script(_tree.root, TransferScreen) as TransferScreen
	if t != null and t.is_visible_in_tree():
		return t
	return null


func _station_body(at: int) -> int:
	for b in SystemLayout.of(Run.map[at]).bodies:
		if b.kind == &"station":
			return b.index
	return -9


## Into the berth at the station the ship is at, the way a player docks: LOCAL
## beside it, then DOCK.
func _dock() -> bool:
	var at := Run.at
	SystemMapScreen._parked[at] = {"at": _station_body(at), "mode": &"rail"}
	SectorScreen._approached_at = at
	if not (Router.current is SectorScreen):
		Router.show_local()
		await Harness.frames(_tree, 4)
	Router.show_station()
	await Harness.frames(_tree, 6)
	return Router.current is StationScreen and Router.docked


## Every item drawn on the left of the move: as an icon in the old hold, or on a
## hardpoint of the old ship.
func _drawn_on_left(t: TransferScreen) -> int:
	var n := 0
	for c in t._old.get_children():
		if c is ItemIcon and not c.is_queued_for_deletion():
			n += 1
	if t._oldpts != null and Run.old_hull != null:
		for raw in Run.pad:
			var m := raw as ModuleData
			if m != null and m.mount >= 0:
				n += 1
	return n


## No two parts on one hardpoint, none on a hardpoint the hull does not have.
func _mounts_valid() -> bool:
	var seen := {}
	for m in Run.installed:
		if m.mount < 0 or m.mount >= Run.slots_for(m.slot):
			return false
		var key := "%d:%d" % [int(m.slot), m.mount]
		if seen.has(key):
			return false
		seen[key] = true
	return true


func _owned_ids() -> Array:
	var ids: Array = []
	for m in Run.installed:
		ids.append(String(m.id))
	for m in Run.cargo:
		ids.append(String(m.id))
	for m in Run.pad:
		ids.append(String(m.id))
	ids.sort()
	return ids


## Into a station that sells a hull, a fresh run.
func _fresh_run_at_station() -> int:
	Rng.forced = 7
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for raw in Run.map:
		(raw as MapGen.MapNode).ambush_rolled = true
		(raw as MapGen.MapNode).ambush_pending = false
	for raw in Run.map:
		var n := raw as MapGen.MapNode
		if n.type == MapGen.NodeType.STATION:
			return n.index
	return -1


# ----------------------------------------------------------------- 1. Jon's

func _jons_save() -> void:
	var raw := FileAccess.get_file_as_string(FIXTURE)
	if not _ok("the fixture is there", raw.length() > 1000):
		return
	var d: Dictionary = JSON.parse_string(raw)
	var want: Array = []
	for k in ["installed", "cargo", "pad"]:
		for e in d[k]:
			want.append(str(e["id"]))
	want.sort()
	var f := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	f.store_string(raw)
	f.close()
	Router.continue_run()
	await Harness.frames(_tree, 6)
	_ok("his run resumed (%s)" % Run.hull.name, Run.hull != null and Run.hull.name == "Medium Frame")
	_ok("nothing he owns is lost (%d of %d)" % [_owned_ids().size(), want.size()],
		_owned_ids() == want)
	_ok("every fitted part is on a hardpoint of its own", _mounts_valid())
	_ok("no move is left to back out of", not Run.can_abandon_move())

	# Docking opens the move: the pad is what holds the door, so the pad is
	# what is shown.
	_ok("he docks at %s" % MapGen.star_name(Run.node_at()), await _dock())
	var t := _transfer()
	if not _ok("the move is open over the station, the pad on it (%d)" % Run.pad.size(),
			t != null and not Run.pad.is_empty()):
		return
	_ok("every pad item is drawn on the left (%d of %d)" % [_drawn_on_left(t), Run.pad.size()],
		_drawn_on_left(t) == Run.pad.size())
	_ok("UNDOCK is refused while it is loaded", not Run.ready_to_fly().is_empty())

	var st := Router.current as StationScreen
	print("  before: fitted %d, hold %d, pad %d, deck %d of a hand of %d" % [Run.installed.size(),
		Run.cargo.size(), Run.pad.size(), Run.deck_size(), Run.hand_size()])
	t._take_all()
	await Harness.frames(_tree, 2)
	print("  TAKE WHAT FITS: fitted %d, hold %d, pad %d, deck %d" % [Run.installed.size(),
		Run.cargo.size(), Run.pad.size(), Run.deck_size()])
	# (all of it fits his Medium Frame: eight on hardpoints, nine in the hold)
	_ok("TAKE WHAT FITS takes all of it, nothing sold or lost (%d left)" % Run.pad.size(),
		Run.pad.is_empty() and _owned_ids() == want)
	t._cast_off()
	await Harness.frames(_tree, 4)
	_ok("CAST OFF stands him in the yard", Router.current == st and _transfer() == null)
	_ok("every fitted part still has its own hardpoint", _mounts_valid())
	_ok("and he may leave (%s)" % "; ".join(Run.ready_to_fly()), Run.ready_to_fly().is_empty())
	_ok("the button says UNDOCK", st._undock != null and not st._undock.disabled)
	st._undock.pressed.emit()
	await Harness.frames(_tree, 20)
	_ok("and UNDOCK lets go", not Router.docked)


# ------------------------------------------------------------------- 2. yard

func _yard_swap() -> void:
	var at := _fresh_run_at_station()
	if not _ok("a run with a station", at >= 0):
		return
	Run.at = at
	Run.map[at].visited = true
	Run.credits = 99999
	var n: MapGen.MapNode = Run.map[at]
	n.shop_hull = LootGen.roll_hull(n.danger)
	n.taken.erase(MapGen.OPTION_SHOP_HULL)
	if not _ok("docked", await _dock()):
		return
	var st := Router.current as StationScreen
	var old_name := Run.hull.name
	var was := _owned_ids()
	var fitted := Run.installed.size()
	# A co-op client's claim still out: a second click on TAKE IT must not pay or move again.
	var pay0 := Run.credits
	st.set(&"_asking", true)
	await st._on_action("take_hull", n.shop_hull)
	await Harness.frames(_tree, 2)
	_ok("a second click while the claim is out does nothing",
		_transfer() == null and Run.credits == pay0 and Run.hull.name == old_name)
	st.set(&"_asking", false)
	await st._on_action("take_hull", n.shop_hull)
	await Harness.frames(_tree, 4)
	var t := _transfer()
	if not _ok("TAKE IT opens the move over the yard", t != null and Router.dock != null):
		return
	_ok("everything is on the pad (%d)" % Run.pad.size(), Run.pad.size() == was.size())
	_ok("all of it drawn (%d)" % _drawn_on_left(t), _drawn_on_left(t) == Run.pad.size())

	# One part across, so the mid-move state has a part on each ship.
	# (one whose slot has a second hardpoint, for the move below)
	var first: ModuleData = null
	for raw in Run.pad:
		if raw is ModuleData and (first == null or Run.slots_for(raw.slot) >= 2):
			first = raw
			if Run.slots_for(raw.slot) >= 2:
				break
	_ok("one part bolts across", first != null and Run.pad_to_mount(first, first.slot, 0))
	# Lifted off its hardpoint and dropped on another of the new ship: it stays there.
	var to := -1
	for i in Run.slots_for(first.slot):
		if Run.module_at(first.slot, i) == null:
			to = i
			break
	if _ok("the part's slot has a second hardpoint", to >= 0):
		t._on_lift(first)
		t._on_mount_drop({module = first}, first.slot, to)
		t._on_release()
		_ok("a part moved to another hardpoint stays there (mount %d, wanted %d)" % [first.mount, to],
			first.mount == to and Run.installed.has(first) and Run.installed.size() == 1)

	# Tab, the key that dropped it: refused, the move stays up.
	await _key(KEY_TAB)
	_ok("Tab leaves the move where it is", _transfer() != null and Router.current is StationScreen)

	# Any other door off the station, and back: it comes back.
	Router.show_system()
	await Harness.frames(_tree, 4)
	_ok("the map refuses to fly the ship with the pad loaded", not Router.may_cast_off())
	Router.show_station()
	await Harness.frames(_tree, 6)
	t = _transfer()
	_ok("back in the berth, the move is open again", t != null)
	if t != null:
		_ok("still all drawn (%d of %d)" % [_drawn_on_left(t), Run.pad.size()],
			_drawn_on_left(t) == Run.pad.size())

	# SAVE AND EXIT, then CONTINUE in this same process: the old frame comes back
	# from the save, and the undo (never saved) does not survive in memory.
	SaveGame.save()
	var kept := FileAccess.get_file_as_string(SaveGame.path)
	Router.show_launcher()
	await Harness.frames(_tree, 3)
	# (what an in-process CONTINUE leaves behind from the run before it: a frame
	# and an undo that belong to objects the load is about to replace)
	Run._undo_move = {hull = Run.hull, hp = 1, paid = 777, node = null, places = {}}
	var f := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	f.store_string(kept)
	f.close()
	Router.continue_run()
	await Harness.frames(_tree, 6)
	_ok("the old frame came back from the save (%s)" % (Run.old_hull.name if Run.old_hull != null else "none"),
		Run.old_hull != null and Run.old_hull.name == old_name)
	_ok("and nothing stale can be backed out of", not Run.can_abandon_move())
	_ok("nothing lost across the save", _owned_ids() == was)
	_ok("the bolted part is still bolted on", Run.installed.size() == 1)
	if not _ok("docked again", await _dock()):
		return
	t = _transfer()
	_ok("the move is open again after CONTINUE", t != null)
	if t == null:
		return
	_ok("every pad item drawn, the old ship wearing its guns (%d of %d)"
		% [_drawn_on_left(t), Run.pad.size()], _drawn_on_left(t) == Run.pad.size())
	t._take_all()
	await Harness.frames(_tree, 2)
	if not Run.pad.is_empty():
		t._sell_rest()
		await Harness.frames(_tree, 2)
	for raw in Run.pad.duplicate():
		Run.take_from_hold(raw)
	t._cast_off()
	await Harness.frames(_tree, 4)
	_ok("the pad is empty and the move is closed", Run.pad.is_empty() and _transfer() == null
		and Run.old_hull == null)
	_ok("%d fitted to start, the new ship can fly (%s)" % [fitted, "; ".join(Run.ready_to_fly())],
		Run.ready_to_fly().is_empty())


# ------------------------------------------------------------------ 3. found

func _found_swap() -> void:
	Rng.forced = 11
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	await Harness.frames(_tree, 6)
	var sc := Router.current as SectorScreen
	if not _ok("in space, on LOCAL", sc != null and not Router.docked):
		return
	var mine := Run.hull
	var was := _owned_ids()
	var fitted := Run.installed.size()
	var found := LootGen.roll_hull(2)
	Run.find_hull(found)
	sc._on_salvage("take_hull", found)
	await Harness.frames(_tree, 4)
	var t := _transfer()
	if not _ok("TRANSFER opens the move in space", t != null):
		return
	_ok("everything is on the pad and drawn (%d of %d)" % [_drawn_on_left(t), Run.pad.size()],
		Run.pad.size() == was.size() and _drawn_on_left(t) == Run.pad.size())
	await _key(KEY_TAB)
	_ok("Tab leaves the move where it is", _transfer() != null)
	_ok("no jump with the pad loaded", not Router.may_cast_off())
	_ok("no SELL out here", t._sell == null or not t._sell.visible)
	_ok("BACK OUT is offered", t._back != null and not t._back.disabled)
	t._back_out()
	await Harness.frames(_tree, 6)
	_ok("BACK OUT puts the old ship back", Run.hull == mine and Run.installed.size() == fitted
		and Run.pad.is_empty() and _owned_ids() == was)
	_ok("and the found hull back on the rail", Run.found_hull == found)
	_ok("and lands on LOCAL, not a station", Router.current is SectorScreen and not Router.docked)

	# Again, and this time through.
	sc = Router.current as SectorScreen
	sc._on_salvage("take_hull", found)
	await Harness.frames(_tree, 4)
	t = _transfer()
	if not _ok("TRANSFER again", t != null):
		return
	t._take_all()
	await Harness.frames(_tree, 2)
	for raw in Run.pad.duplicate():
		Run.take_from_hold(raw)
	t._cast_off()
	await Harness.frames(_tree, 6)
	_ok("CAST OFF lands on LOCAL, not a station", Router.current is SectorScreen and not Router.docked)
	_ok("flying the found hull", Run.hull == found and Run.found_hull == null)
	_ok("and free to jump", Router.may_cast_off())
