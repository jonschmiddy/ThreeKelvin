extends Node

## SCRATCH (scratch/tag-calm): a film of the hull tag under `tagcalm=N`: hover the hull for
## `hold=` seconds, then off; `quick=1` adds hull, heat, fuel, scrap, 1.4 s each. 960x540.

var _tree: SceneTree


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


func _run() -> void:
	_tree = get_tree()
	await _frames(2)
	HoloTag.calm = int(_arg("tagcalm", "0"))
	var hold := float(_arg("hold", "8"))
	get_window().size = Vector2i(960, 540)
	await _frames(8)
	print("[film] calm %d" % HoloTag.calm)
	Router.animate_in_harness = true
	Rng.forced = 4242
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
	var away := Vector2(480, 300)
	await _hover(away)
	await _wait(0.5)
	var hud := Router.hud
	print("[film] hull at %.3f" % GameClock.now())
	var hr := hud._hull.get_global_rect()
	print("[film] rect %d %d %d %d" % [hr.position.x, hr.position.y, hr.size.x, hr.size.y])
	await _hover(hud._hull.get_global_rect().get_center())
	await _wait(hold)
	await _hover(away)
	print("[film] off at %.3f" % GameClock.now())
	await _wait(0.8)
	if _arg("quick", "0") == "1":
		print("[film] quick at %.3f" % GameClock.now())
		var qi := 0
		for c: Control in [hud._hull, hud._heat, hud._hull, hud._heat]:
			qi += 1
			print("[film] q%d at %.3f %s" % [qi, GameClock.now(), c.get_global_rect()])
			await _hover(c.get_global_rect().get_center())
			await _wait(1.4)
		await _hover(away)
		await _wait(0.6)
	print("[film] done at %.3f" % GameClock.now())
	_tree.quit()
