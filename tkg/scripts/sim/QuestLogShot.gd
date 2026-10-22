extends Node

## THE QUESTS ON THE STAR CHART, photographed:
##   godot --path . -- sheet=QuestLogShot out=<dir> [seed=N]
## `quests_0.png`: none held, the plain line. `quests_1.png`: one, picked, its
## route from YOU. `quests_4.png`: four (a fetch READY to hand in, a hunt, a
## heat quest part carried, a fetch), the hunt picked. Each is the whole
## window, scaled to 1920x1080 where the window could not be made that big (the
## game is a 960x540 canvas drawn at 2x). Needs a window.

var _tree: SceneTree
var _out := ""


func _arg(k: String, d: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with(k + "="):
			return (a as String).substr(k.length() + 1)
	return d


func _ready() -> void:
	_run.call_deferred()


func _secs(s: float) -> void:
	var t0 := GameClock.now()
	while GameClock.now() - t0 < s:
		await _tree.process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := _tree.root.get_texture().get_image()
	if img.get_width() < 1920:
		img.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [_out, name])
	print("[questlogshot] wrote %s/%s.png" % [_out, name])


func _run() -> void:
	_tree = get_tree()
	_out = _arg("out", "user://questlogshot")
	DirAccess.make_dir_recursive_absolute(_out)
	DisplaySettings.reduced_motion = true
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.SYSTEM and n.layer == 3:
			Run.at = n.index
			n.visited = true
			break
	Run.chart_from(Run.node_at())
	QuestLog.forget()
	StarchartScreen._side_quests = true

	await _chart("quests_0", -1)
	_sign([ContractData.Kind.HUNT])
	await _chart("quests_1", 0)
	_sign([ContractData.Kind.FETCH, ContractData.Kind.HEAT, ContractData.Kind.FETCH])
	# the first fetch done, some heat on the hull, the hunt picked
	var fetch: ContractData = null
	for raw in Run.contracts:
		if (raw as ContractData).kind == ContractData.Kind.FETCH:
			fetch = raw
			break
	Run.reach_contract_target(fetch.at)
	Run.heat = 3
	await _chart("quests_4", 0)
	StarchartScreen._side_quests = false
	_tree.quit(0)


func _sign(kinds: Array) -> void:
	for kind in kinds:
		var got := false
		for raw in Run.map:
			if got:
				break
			for c in Contracts.board(raw as MapGen.MapNode):
				var job: ContractData = c
				if job.kind != kind or Run.holds_contract(job):
					continue
				if job.at >= 0 and (job.at == Run.at or QuestLog.jumps(job.at) < 1 or QuestLog.jumps(job.at) > 4):
					continue
				var mine := Run.take_contract(job)
				print("[questlogshot] signed: %s" % mine.status_line())
				got = true
				break


## The chart on QUESTS, card `pick` pressed (-1: none), framed on the quests.
func _chart(name: String, pick: int) -> void:
	Router.show_starchart()
	await _secs(1.5)
	var ch := Router.current as StarchartScreen
	ch.dismiss_primer()
	var span := 0.1
	for e in QuestLog.entries():
		if int((e as Dictionary).place) >= 0:
			span = maxf(span, MapGen.hop_distance(Run.node_at(), Run.map[int((e as Dictionary).place)]) + 0.03)
	ch._chart.frame_region(Run.node_at(), span, false)
	ch._refresh()
	await _secs(0.5)
	if pick >= 0:
		var cards: Array = []
		for c in ch._quests.get_children():
			if c is Button and c.has_meta(&"quest"):
				cards.append(c)
		# the hunt, where there is one
		var b: Button = cards[mini(pick, cards.size() - 1)] if not cards.is_empty() else null
		for c in cards:
			for raw in Run.contracts:
				var job: ContractData = raw
				if job.id == int(c.get_meta(&"quest")) and job.kind == ContractData.Kind.HUNT:
					b = c
		if b != null:
			b.pressed.emit()
	await _secs(2.0)
	print("[questlogshot] %s: tab %s, tags %s" % [name, ch._tab_quests.get_global_rect(), ch._chart.quest_rects])
	await _shot(name)
