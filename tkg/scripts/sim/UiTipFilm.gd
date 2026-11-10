extends Node

## A film of one tooltip look (`tiplook=N`) opening and holding: the HUD's hull tip on LOCAL, then
## END TURN and the word VENT in a fight, each held `hold=` seconds (2.5); `only=hull` stops after
## the first. The window at the game's own 960x540, so the writer's frames are game pixels; every
## wait on `GameClock`. docs/tests.md has the command.

var _tree: SceneTree
var _hold := 2.5


func _ready() -> void:
	_run.call_deferred()


func _arg(k: String, d: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with(k + "="):
			return (a as String).substr(k.length() + 1)
	return d


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _wait(s: float) -> void:
	var t := GameClock.now()
	while GameClock.now() - t < s:
		await _tree.process_frame


func _hover(at: Vector2) -> void:
	_tree.root.warp_mouse(at)
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	Input.parse_input_event(mm)
	await _frames(2)


func _screen() -> SectorScreen:
	return Router.current as SectorScreen


func _local() -> void:
	Router.animate_in_harness = true
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for n: MapGen.MapNode in Run.map:
		if n.index > 0 and n.type == MapGen.NodeType.SYSTEM and not n.cleared \
				and n.region != MapGen.Region.FAUNA:
			Run.at = n.index
			break
	Run.map[Run.at].visited = true
	SectorScreen._approached_at = Run.at
	Router.show_local()
	await _wait(6.0)


func _fight() -> SectorScreen:
	Router.start_combat(DB.enemies[&"cutter"], [], false, true)
	for i in 1800:
		await _tree.process_frame
		var sc := _screen()
		if sc != null and sc.fighting() and not sc._hold and not sc._opening \
				and sc._hand != null and sc._hand._views.size() > 0 and i > 120:
			break
	await _wait(1.5)
	return _screen()


func _run() -> void:
	_tree = get_tree()
	await _frames(2)
	_hold = float(_arg("hold", "2.5"))
	TornTag.look = int(_arg("tiplook", str(TornTag.DEFAULT_LOOK)))
	get_window().size = Vector2i(960, 540)
	await _frames(8)
	print("[film] look %d %s" % [TornTag.look, TipFrames.NAMES[TornTag.look]])
	await _local()
	await _hover(Vector2(480, 300))
	await _wait(0.5)
	print("[film] hull at %.2f" % GameClock.now())
	await _hover(Router.hud._hull.get_global_rect().get_center())
	await _wait(TagLayer.DELAY + _hold)
	await _hover(Vector2(480, 300))
	await _wait(0.4)
	if _arg("only", "") == "hull":
		print("[film] done at %.1f s" % GameClock.now())
		_tree.quit()
		return
	var sc := await _fight()
	if sc == null:
		_tree.quit()
		return
	print("[film] endturn at %.2f" % GameClock.now())
	await _hover(sc._end_button.get_global_rect().get_center())
	await _wait(TagLayer.DELAY + _hold)
	await _hover(Vector2(480, 300))
	await _wait(0.4)
	var v: CardView = null
	for cv: CardView in sc._hand._views:
		if is_instance_valid(cv) and not cv.card.keywords().is_empty():
			v = cv
			break
	if v != null:
		var r := v.get_global_rect()
		var at := r.position + Vector2(CardView.Z_TEXT.position.x + 8.0, CardView.Z_TEXT.position.y - 3.0)
		print("[film] word at %.2f" % GameClock.now())
		await _hover(at)
		await _wait(0.4)
		await _hover(at)
		await _wait(_hold)
	await _hover(Vector2(480, 300))
	await _wait(0.5)
	print("[film] done at %.1f s" % GameClock.now())
	_tree.quit()
