extends Node

## A science mini game opened from the command line, on the desk in a real run: `-- minigame
## coolant depth=3 sensors=1` picks THE FIRST LOOK on LOCAL with that game forced. `auto=1` plays
## it by script through the glass (`fail=1` gives up), `out=<dir>` writes stills, `quit=1` quits.
## Why: docs/why/MiniGame.md#tests

const SITE := &"the_first_look"

var _tree: SceneTree
var _h := Harness.new()
var _out := ""


func _ready() -> void:
	_run.call_deferred()


## The game's id: the word after `minigame` (coolant when none).
func _id() -> StringName:
	var argv := OS.get_cmdline_user_args()
	var k := argv.find("minigame")
	if k >= 0 and k + 1 < argv.size() and not argv[k + 1].contains("="):
		return StringName(argv[k + 1])
	return &"coolant"


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


func _until(cond: Callable, limit: int = 2400) -> bool:
	for k in limit:
		if cond.call():
			return true
		await _tree.process_frame
	return bool(cond.call())


## Scene seconds on the desk's own clock (the game ticks on it).
func _wait(d: DeskScene, secs: float) -> void:
	var to := d.real + secs
	await _until(func() -> bool: return d.real >= to)


func _run() -> void:
	_tree = get_tree()
	_out = Harness.arg("out")
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	await Harness.frames(_tree, 2)
	Rng.forced = int(Harness.arg("seed", "4242"))
	var id := _id()
	var force := {id = id}
	for k: String in ["depth", "sensors"]:
		if Harness.arg(k) != "":
			force[k] = int(Harness.arg(k))
	MiniGames.force = force
	var wt := {"light": HullData.Weight.LIGHT, "heavy": HullData.Weight.HEAVY}.get(Harness.arg("weight"), HullData.Weight.MEDIUM) as int
	Run.start_new_run(&"korvan", wt)
	var n := _system()
	if n == null:
		_h._fail("no system to read in")
		_end()
		return
	var sc := await _local_with_reading(n)
	if sc == null:
		_h._fail("LOCAL did not come up with the reading")
		_end()
		return
	var data0 := Run.data
	var pile0 := OptionResolve.pile_now(n)
	sc._events.choose(0)
	await _until(func() -> bool: return _desk() != null, 30)
	var d := _desk()
	if not _h._ok("the reading opens the desk with %s" % id, d != null and String(d._deal.get("id", "")) == String(id)):
		_end()
		return
	if Harness.arg("auto") == "":
		return
	await _play(d, n, sc, data0, pile0)


func _play(d: DeskScene, n: MapGen.MapNode, sc: SectorScreen, data0: int, pile0: Array) -> void:
	await _until(func() -> bool: return d.ts >= DeskTimeline.A + d.room.life.title_u + 1.0)
	await _shot("1_card")
	d.tap()
	_h._ok("the tap starts the game, nothing taken yet", d.game != null and d.game.playing() and Run.data == data0)
	await _wait(d, 1.6)
	await _shot("2_start")
	var g := d.game.game
	var taps := CoolantSolver.taps(g as GameCoolant) if g is GameCoolant else CentrifugeSolver.taps(g as GameCentrifuge)
	var fail := Harness.arg("fail") != ""
	for k in taps.size():
		if fail and k == taps.size() / 2:
			var esc := InputEventAction.new()
			esc.action = &"ui_cancel"
			esc.pressed = true
			Input.parse_input_event(esc)
			await Harness.frames(_tree, 3)
			break
		_click(d, taps[k] + d.game.at)
		await _wait(d, 0.45)
		if k == taps.size() / 2:
			await _shot("3_mid")
	if g is GameCentrifuge and not fail:
		await _wait(d, 1.0)
		await _shot("3b_spin")
	await _until(func() -> bool: return d.game.revealed)
	await _wait(d, 1.0)
	await _shot("4_result")
	var gained := OptionResolve.pile_gained(n, pile0)
	print("minigame %s: score %.2f, tier %s, haul %s (%s)" % [g.id(), d.game.score,
		ScienceHaul.TIER_NAMES[d.game.tier], d.game.haul, d.game.detail])
	_h._ok("the game's end took the reading once (DATA +%d)" % (Run.data - data0), Run.data - data0 == OptionTable.reading(1))
	_h._ok("and paid its haul, a material in the system (%d)" % gained, gained >= 1 and d.game.haul != "")
	_h._ok("a %s run scores as it should (%.2f)" % ["given-up" if fail else "clean", d.game.score],
		d.game.score <= 0.2 if fail else d.game.score >= 0.95)
	if Harness.arg("quit") != "":
		d.tap()
		await _until(func() -> bool: return _desk() == null, 1200)
		await Harness.frames(_tree, 90)
		await _shot("5_local")
		_h._ok("back on LOCAL with the result page", sc._events.page == &"result")
		_end()


## A click at glass point `gp`: found on the screen through the tube's curve, sent as the mouse.
func _click(d: DeskScene, gp: Vector2i) -> void:
	var c := Vector2(DeskRoom.GLASS_C.position) + Vector2(gp) * 5.0 + Vector2(2.5, 2.5)
	for k in 8:
		var got := d.room.glass_at(c)
		if got == gp:
			break
		c += Vector2(gp - got) * 5.0
	var at := c * d.size / DeskRoom.CANVAS
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		d._gui_input(ev)


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


func _end() -> void:
	_h.verdict("minigame")
	_tree.quit(_h.code())
