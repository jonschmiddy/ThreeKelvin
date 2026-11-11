extends Node

## SCRATCH (scratch/tag-calm): a film of a tag under `tagcalm=N tagglitch=G` (read by
## `HoloTag.read_dial`). `shot=hull`: hover LOCAL's hull readout for `hold=` seconds, then off;
## `quick=1` adds hull, heat, 1.4 s each. `shot=sys`: the system map, an event's beacon pointed
## at (held on it as it moves) for `hold=` seconds; `steps=T:SHARE,...` sets the hull as it runs.
## 960x540; timing on GameClock.

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
	HoloTag.read_dial()
	var hold := float(_arg("hold", "8"))
	get_window().size = Vector2i(960, 540)
	await _frames(8)
	print("[film] calm %d glitch %d" % [HoloTag.calm, HoloTag.glitch])
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
	if _arg("shot", "hull") == "sys":
		await _sys(hold)
	else:
		await _hull(hold)
	print("[film] done at %.3f" % GameClock.now())
	_tree.quit()


func _sys(hold: float) -> void:
	Router.show_system()
	await _wait(7.0)
	var sm := Router.current as SystemMapScreen
	if sm == null:
		print("[film] ERROR no system map: %s" % Router.current)
		return
	var away := Vector2(8, 530)
	await _hover(away)
	await _wait(0.5)
	var ov = sm.overlay
	var pick := -1
	for i in (ov.beacons_at as Array).size():
		var e: Array = ov.beacons_at[i]
		if e[2] != null and int(e[2].opt) >= 0:
			pick = i
			break
	if pick < 0 and (ov.beacons_at as Array).size() > 0:
		pick = 0
	print("[film] beacons %d pick %d" % [(ov.beacons_at as Array).size(), pick])
	print("[film] hull at %.3f" % GameClock.now())
	var t0 := GameClock.now()
	var logged := false
	# `steps=T:SHARE,...`: the hull set to SHARE of its max T s after the tag opens
	var steps: Array = []
	for st in _arg("steps", "").split(",", false):
		var kv := (st as String).split(":")
		steps.append([float(kv[0]), float(kv[1])])
	while GameClock.now() - t0 < hold:
		while not steps.is_empty() and GameClock.now() - t0 >= float(steps[0][0]):
			Run.hp = maxi(1, int(floorf(Run.max_hp() * float(steps[0][1]) + 0.00001)))
			SectorScreen.shown_hull = -1
			Sig.resources_changed.emit()
			print("[film] hp %d/%d at %.3f" % [Run.hp, Run.max_hp(), GameClock.now()])
			steps.pop_front()
		var h: Dictionary = {}
		if pick >= 0 and pick < (ov.beacons_at as Array).size():
			h = ov.hit((ov.beacons_at[pick] as Array)[0])
		ov.hover = h
		await _tree.process_frame
		if not logged and GameClock.now() - t0 > 0.5:
			logged = true
			var gr: Rect2 = ov.get_global_transform_with_canvas() * (ov.tip_rect as Rect2)
			print("[film] rect %d %d %d %d" % [gr.position.x, gr.position.y, gr.size.x, gr.size.y])
	ov.hover = {}
	print("[film] off at %.3f" % GameClock.now())
	await _wait(0.6)


func _hull(hold: float) -> void:
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
