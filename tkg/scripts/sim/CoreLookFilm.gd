extends Node

## LOCAL AT THE CORE, filmed (its hole as the world you orbit, `LocalSky`):
##   godot --path . --resolution 1920x1080 --write-movie <dir>/f.png --fixed-fps 60
##       -- sheet=CoreLookFilm [secs=4]
## Opens LOCAL at the core the way the sector map does (`Router.show_local`),
## waits two seconds for the sky to come up whole, prints the frame the film
## proper starts on, holds `secs` seconds and quits. Every clock in the picture
## is the game's (the sky's `t`, the hole's `step`), and the hull's bob is put
## on it too (`ShipView.shot_clock`), so the movie writer's frames are true
## speed however slowly they were drawn.

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
