extends Node

## The science desk end to end in a real run, windowed (`render.sh`): a reading picked on LOCAL,
## the push in, the room, the card, the tap (taken once), the outcome, back to LOCAL; then a visit
## left with Esc before the tap. `-- sheet=DeskVisit [out=<dir>] [weight=light|medium|heavy] [manufacturer=<id>]`
## writes a still of each beat; the hull picks the room (Jon's ruling: light the bunk, heavy DESK 2).
## Why: docs/why/DeskScene.md#the-hook

const SITE := &"the_first_look"

var _tree: SceneTree
var _h := Harness.new()
var _out := ""


func _ready() -> void:
	_run.call_deferred()


func _arg(k: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return ""


func _shot(name: String) -> void:
	if _out == "":
		return
	await RenderingServer.frame_post_draw
	_tree.root.get_texture().get_image().save_png(_out.path_join(name + ".png"))


func _desk() -> DeskScene:
	for c: Node in _tree.root.find_children("*", "Control", true, false):
		if c is DeskScene and not (c as DeskScene)._done:
			return c as DeskScene
	return null


## Frames until `cond` holds, at most `limit`; whether it did.
func _until(cond: Callable, limit: int = 2400) -> bool:
	for k in limit:
		if cond.call():
			return true
		await _tree.process_frame
	return bool(cond.call())


func _system() -> MapGen.MapNode:
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.SYSTEM:
			OptionTable.ensure(m)
			return m
	return null


func _local_with_reading(n: MapGen.MapNode) -> SectorScreen:
	n.options.clear()
	n.options.append(SITE)
	n.taken.clear()
	n.results.clear()
	n.left.clear()
	Run.at = n.index
	Run.fuel = Run.FUEL_TANK
	Router.show_local()
	await Harness.frames(_tree, 150)
	var sc := Router.current as SectorScreen
	if sc == null:
		return null
	sc._events.open(0)
	await Harness.frames(_tree, 120)
	if sc._events.text != null and not sc._events.text.done:
		sc._events.text.skip()
	await Harness.frames(_tree, 30)
	return sc


func _run() -> void:
	_tree = get_tree()
	_out = _arg("out")
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	await Harness.frames(_tree, 2)
	Rng.forced = 4242
	var wt := {"light": HullData.Weight.LIGHT, "heavy": HullData.Weight.HEAVY}.get(_arg("weight"), HullData.Weight.MEDIUM) as int
	var mf := StringName(_arg("manufacturer")) if _arg("manufacturer") != "" else &"korvan"
	Run.start_new_run(mf, wt)
	var want := DeskScene.room_for(Run.hull)
	var n := _system()
	if not _h._ok("a system to read in", n != null):
		_end()
		return
	var sc := await _local_with_reading(n)
	if not _h._ok("LOCAL is up with the reading's band", sc != null and sc._events.page == &"event"):
		_end()
		return
	await _shot("1_local")
	var data0 := Run.data
	var pays := OptionTable.reading(1)
	sc._events.choose(0)
	var up := await _until(func() -> bool: return _desk() != null, 30)
	_h._ok("picking the reading opens the desk", up)
	var d := _desk()
	if d == null:
		_end()
		return
	_h._ok("the room is the hull's, %s (Jon's ruling)" % want, d.room.id == want)
	print("deskvisit: pushing into the ship at %s" % str(d._ship))
	await _until(func() -> bool: return d.ts >= 1.6)
	await _shot("2_push_in")
	await _until(func() -> bool: return d.ts >= DeskTimeline.A + 2.0)
	_h._ok("in the room the shell shows the desk's canvas", GameShell.instance == null or GameShell.covered())
	await _shot("3_desk_power_on")
	var title_up := DeskTimeline.A + d.room.life.title_u + 1.0
	await _until(func() -> bool: return d.ts >= title_up)
	await _shot("4_title_card")
	_h._ok("nothing is taken before the tap", Run.data == data0 and not d.taken)
	d.tap()
	await _until(func() -> bool: return d._shown_at >= 0.0, 600)
	await _until(func() -> bool: return d.ts >= d._shown_at + 1.5)
	await _shot("5_outcome")
	_h._ok("the tap took the reading once (DATA +%d, now +%d)" % [pays, Run.data - data0], Run.data - data0 == pays)
	d.tap()
	_h._ok("a tap after the outcome leaves", d.leaving)
	await _until(func() -> bool: return d.leaving and d.ts <= 4.0)
	await _shot("6_leaving")
	await _until(func() -> bool: return d.ts <= 1.4)
	await _shot("7_push_out")
	var gone := await _until(func() -> bool: return _desk() == null, 1200)
	_h._ok("the visit ends back on LOCAL", gone and Router.current == sc)
	_h._ok("the shell shows the game again", GameShell.instance == null or not GameShell.covered())
	await Harness.frames(_tree, 90)
	await _shot("8_back_on_local")
	_h._ok("LOCAL shows the reading's result", sc._events.page == &"result")
	_h._ok("and only once (DATA +%d)" % (Run.data - data0), Run.data - data0 == pays)
	# a second visit, left with Esc before the tap
	sc = await _local_with_reading(n)
	var data1 := Run.data
	sc._events.choose(0)
	await _until(func() -> bool: return _desk() != null, 30)
	d = _desk()
	if d != null:
		await _until(func() -> bool: return d.ts >= DeskTimeline.A + 3.0)
		var esc := InputEventAction.new()
		esc.action = &"ui_cancel"
		esc.pressed = true
		Input.parse_input_event(esc)
		await Harness.frames(_tree, 3)
		_h._ok("Esc leaves the desk", d.leaving)
		await _until(func() -> bool: return _desk() == null, 1200)
	_h._ok("left before the tap: nothing taken (DATA +%d), the event still up" % (Run.data - data1),
		Run.data == data1 and n.taken.is_empty() and sc._events.page == &"event")
	_end()


func _end() -> void:
	_h.verdict("deskvisit")
	_tree.quit(1 if _h._fails > 0 else 0)
