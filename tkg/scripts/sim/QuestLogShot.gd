extends Node

## THE QUESTS TABLE, photographed:
##   godot --path . -- sheet=QuestLogShot out=<dir> [seed=N]
## Over LOCAL, opened by the HUD's QUESTS tab: `quests_0.png` none held, the
## plain line; `quests_1.png` one, its row open; `quests_4.png` four (a fetch
## READY to hand in, a hunt, a heat quest part carried, a fetch), the hunt's
## row open. Then `chart_show.png`: the chart after the hunt's SHOW ON
## STARCHART, and `chart_route.png` after its PLOT ROUTE. With `events=1`,
## only `event_quests.png`: an event quest beside a job, and COMPLETED
## (`_events`). Each is the whole
## window, scaled to 1920x1080 where the window could not be made that big (the
## game is a 960x540 canvas drawn at 2x). Needs a window, and a fresh APPDATA:
## a stale shader cache whitens the sky.

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
	QuestPanel.picked = -1
	if _arg("events") != "":
		await _events()
		_tree.quit(0)
		return

	await _table("quests_0")
	var hunt := _sign([ContractData.Kind.HUNT])
	QuestPanel.picked = hunt.id
	await _table("quests_1")
	_sign([ContractData.Kind.FETCH, ContractData.Kind.HEAT, ContractData.Kind.FETCH])
	var fetch: ContractData = null
	for raw in Run.contracts:
		if (raw as ContractData).kind == ContractData.Kind.FETCH:
			fetch = raw
			break
	Run.reach_contract_target(fetch.at)
	Run.heat = 3
	await _table("quests_4")
	QuestPanel.show_on_chart(hunt.id, false)
	await _secs(2.5)
	await _shot("chart_show")
	Router.show_local()
	await _secs(1.0)
	QuestPanel.show_on_chart(hunt.id, true)
	await _secs(2.5)
	await _shot("chart_route")
	_tree.quit(0)


## `events=1`: `event_quests.png`, the table with both sections. Open: a
## signed hunt and the runner's parcel (its row open); COMPLETED: a fetch
## handed in.
func _events() -> void:
	var fetch := _sign([ContractData.Kind.FETCH])
	var hunt := _sign([ContractData.Kind.HUNT])
	if fetch != null:
		fetch.state = ContractData.State.READY
		Run.deliver_contract(fetch)
	var here := Run.node_at()
	OptionTable.ensure(here)
	here.options.append(&"the_runner")
	SkillCheck.forced = SkillCheck.Band.CLEAN
	await OptionResolve.take(here, here.options.size() - 1, 0)
	SkillCheck.forced = -1
	QuestLog.forget()
	for e in QuestLog.entries():
		if bool((e as Dictionary).event):
			QuestPanel.picked = int((e as Dictionary).id)
	print("[questlogshot] hunt %s, picked %d" % [hunt != null, QuestPanel.picked])
	await _table("event_quests")


func _sign(kinds: Array) -> ContractData:
	var last: ContractData = null
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
				last = Run.take_contract(job)
				print("[questlogshot] signed: %s" % last.status_line())
				got = true
				break
	return last


## LOCAL, the QUESTS tab pressed.
func _table(name: String) -> void:
	QuestPanel.close()
	Router.show_local()
	await _secs(2.0)
	Router.hud._tab_quests.pressed.emit()
	await _secs(1.0)
	print("[questlogshot] %s: tab %s, table %s" % [name, Router.hud.quests_tab_rect(),
		QuestPanel._open.get_global_rect() if QuestPanel.is_open() else Rect2()])
	await _shot(name)
