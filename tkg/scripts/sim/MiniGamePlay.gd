class_name MiniGamePlay
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
	if Harness.arg("site") != "":
		force.site = StringName(Harness.arg("site"))
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
	# the boot screen's last line, typed just before the title card: the site being read
	await _until(func() -> bool: return d.ts >= DeskTimeline.A + d.room.life.title_u - 0.04)
	await _shot("0_boot")
	print("minigame: the boot screen types the site, %s" % LocalEventDrawer.place_name(n, 0))
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
	var fail := Harness.arg("fail") != ""
	await _drive(d, g, fail)
	await _until(func() -> bool: return d.game.revealed)
	await _wait(d, 1.0)
	await _shot("4_result")
	var gained := OptionResolve.pile_gained(n, pile0)
	print("minigame %s: score %.2f, tier %s, haul %s (%s)" % [g.id(), d.game.score,
		String(ScienceHaul.tier_key(d.game.tier)).to_upper(), d.game.haul, d.game.detail])
	_h._ok("the game's end took the reading once (DATA +%d)" % (Run.data - data0), Run.data - data0 == OptionTable.reading(1))
	_h._ok("and paid its haul, a material in the system (%d)" % gained, gained >= 1 and d.game.haul != "")
	# the line on the glass is the row the take paid, from the site's own source (`site=` stands in another)
	var paid: Dictionary = d.result.get("haul", {})
	var site := StringName(MiniGames.force.get("site", OptionTable.by_id(StringName(Harness.arg("event", String(SITE)))).get("site", &"")))
	var row: Dictionary = {}
	for r: Dictionary in MaterialTable.all():
		if String(r.name) == String(paid.get("name", "")):
			row = r
	var drawn := "%s [%s]" % [d.game.haul, String(d.game.haul_tier).to_upper()]
	var want := "%s [%s]" % [paid.get("name", ""), String(paid.get("tier", &"")).to_upper()]
	_h._ok("the result card is up and reads the paid row, %s, a %s material (site %s)" % [drawn, ScienceHaul.source_of(site), site],
		d.game.card_up() and not paid.is_empty() and drawn == want and not row.is_empty() and StringName(row.source) == ScienceHaul.source_of(site))
	_h._ok("the card's word is the game's end (%s)" % d.game.end_text, d.game.end_text == (MiniShell.GAVE_UP if fail else g.end_text) and d.game.end_text != "")
	_h._ok("a %s run scores as it should (%.2f)" % ["given-up" if fail else "clean", d.game.score],
		d.game.score <= 0.2 if fail else d.game.score >= 0.95)
	if Harness.arg("quit") != "":
		# A (Nov 20): a click anywhere on the glass leaves once the card is up, LEAVE or not
		click_glass(d, Vector2(20, 110))
		_h._ok("a click on the result card's glass, off LEAVE, leaves", d.leaving)
		await _until(func() -> bool: return _desk() == null, 1200)
		await Harness.frames(_tree, 90)
		await _shot("5_local")
		_h._ok("back on LOCAL with the result page", sc._events.page == &"result")
		_end()


## The scripted player through the screen: a gesture (down to up) every 0.45 s (or its own longer wait) for a planned
## run, the pilots every frame; `fail` plays a plan's first gesture, then gives up with Esc 2 s in (A: no GIVE UP on the glass). Stills mid-way and, after a plan, a beat on.
func _drive(d: DeskScene, g: MiniGame, fail: bool) -> void:
	var sv := MiniSolver.for_game(g)
	var total := sv.plan.size()
	var queue: Array[Dictionary] = sv.plan.duplicate()
	var sent := 0
	var t0 := d.real
	var mid := false
	while not g.is_done() and d.real - t0 < 150.0:
		if fail and d.real - t0 > 2.0:
			for down: bool in [true, false]:
				var esc := InputEventAction.new()
				esc.action = &"ui_cancel"
				esc.pressed = down
				Input.parse_input_event(esc)
				await Harness.frames(_tree, 2)
			return
		if total > 0:
			if fail and sent > 0:
				# a give-up plays the plan's first gesture only, so a short plan (Pulsar's two) never wins
				# first and a game that pays for progress on a give-up (Anomaly) still pays little
				await _tree.process_frame
				continue
			if queue.is_empty():
				break
			var hold := 0.45
			while not queue.is_empty():
				var e: Dictionary = queue.pop_front()
				_send(d, e)
				sent += 1
				await _tree.process_frame
				if e.k == "up":
					# a plan's longer wait holds (Seismic's sweep and drill ignore taps while busy)
					hold = maxf(hold, float(e.get("wait", 0.0)))
					break
			await _wait(d, hold)
		else:
			for e in sv.act(g, 1.0 / 60.0):
				_send(d, e)
			await _tree.process_frame
		if not mid and ((total > 0 and sent >= total / 2) or (total == 0 and d.real - t0 > 6.0)):
			mid = true
			await _shot("3_mid")
	if total > 0 and not g.is_done():
		await _wait(d, 1.0)
		await _shot("3b_after")


## One scripted event onto the screen: a canvas point through the glass and the tube's curve.
func _send(d: DeskScene, e: Dictionary) -> void:
	if e.k == "key" or e.k == "keyup":
		var ev := InputEventKey.new()
		ev.physical_keycode = {&"w": KEY_W, &"a": KEY_A, &"d": KEY_D}[e.key]
		ev.pressed = e.k == "key"
		d._input(ev)
		return
	var at := screen_of(d, (e.p as Vector2) + Vector2(d.game.at))
	if e.k == "move":
		var mv := InputEventMouseMotion.new()
		mv.position = at
		d._gui_input(mv)
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = e.k == "down"
	ev.position = at
	d._gui_input(ev)


## The screen point over glass point `gp`: found through the tube's curve (`DeskRoom.glass_at_f`).
static func screen_of(d: DeskScene, gp: Vector2) -> Vector2:
	var c := Vector2(DeskRoom.GLASS_C.position) + gp * 5.0
	for k in 8:
		var got := d.room.glass_at_f(c)
		if (got - gp).length() < 0.05:
			break
		c += (gp - got) * 5.0
	return c * d.size / DeskRoom.CANVAS


## A left click at glass point `gp`, through the desk's own input.
static func click_glass(d: DeskScene, gp: Vector2) -> void:
	for down: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = screen_of(d, gp)
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
	n.options.append(StringName(Harness.arg("event", String(SITE))))
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
