extends Node

## Every clock is the game's and the hull bob is put on it too, so movie frames are true speed.
## Why: docs/why/CoreLookFilm.md#core-look-film

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	var args := OS.get_cmdline_user_args()
	var secs := 4.0
	for a in args:
		if a.begins_with("secs="):
			secs = float(a.substr(5))
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.CORE:
			Run.at = n.index
	SectorScreen._approached_at = Run.at
	Router.show_local()
	var t := 0.0
	var start := -1
	var total := 2.0 + secs
	while t < total:
		ShipView.shot_clock = t
		if t >= 2.0 and start < 0:
			start = Engine.get_process_frames()
			print("corelookfilm: film starts at %.3f s" % t)
		await tree.process_frame
		t += 1.0 / 60.0
	ShipView.shot_clock = -1.0
	tree.quit()
