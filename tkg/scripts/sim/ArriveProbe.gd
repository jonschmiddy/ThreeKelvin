extends Node

## A NEW RUN'S FIRST ARRIVAL ON LOCAL, measured a frame at a time:
##   godot --path . --windowed --position 3840,0 -- sheet=ArriveProbe out=<file.tsv>
##       [secs=11] [mouse=<x>,<y>] [hover=<frame>] [intro]
## A new run launched the way the hull pick launches it (`Router.show_local`),
## and for every real frame: its wall length (ms, the hitch is a wall question),
## the game clock, what the engines are doing (`ShipView._thrust_now`, -1 = no
## flame), the arrival window, whether the cutaway outline shows, the screen's
## phase, and every mouse event the ship's slot was handed. `mouse=x,y` puts
## the pointer there (window pixels) before the run starts and leaves it: the
## pointer left over the launch button, with the parked ship ending up under
## it (not on the hidden render desktop, which has no pointer to warp). `hover=N` shows the cutaway outline from frame N, as a pointer resting
## on the parked ship would, to time what drawing it costs. Prints the hull's
## rect at rest, to aim it with. Run it
## WITHOUT --fixed-fps: a fixed step hides the frames that stall. Needs a window.

var _args: PackedStringArray
var _events: Array[String] = []


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	Router.animate_in_harness = true
	FirstRunIntro.mark_seen(false)
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var mouse := _arg("mouse")
	if mouse != "":
		var xy := mouse.split(",")
		get_viewport().warp_mouse(Vector2(float(xy[0]), float(xy[1])))
		await tree.process_frame
	Router.show_local()
	if "intro" in _args:
		FirstRunIntro.maybe_start()
	var out := FileAccess.open(_arg("out", "user://arrive_probe.tsv"), FileAccess.WRITE)
	out.store_line("frame\twall_ms\tgame_s\tthrust\twindow\tarriving\toutline\tphase\tevents")
	var frames := int(float(_arg("secs", "11")) * 60.0)
	var hooked: Control = null
	var last := Time.get_ticks_usec()
	var worst := 0.0
	var worst_at := -1
	for i in frames:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		var ms := float(now - last) / 1000.0
		last = now
		var sc := Router.current as SectorScreen
		var art: ShipView = sc._view.ship_view() if sc != null and sc._view != null else null
		if art != null and hooked == null and art.get_parent() is Control:
			hooked = art.get_parent() as Control
			hooked.gui_input.connect(func(e: InputEvent) -> void:
				var mm := e as InputEventMouseMotion
				_events.append("%s%s" % [e.get_class(), (" rel=%s" % mm.relative) if mm != null else ""]))
		if i == int(_arg("hover", "-1")) and sc != null and sc._ship_outline != null:
			sc._ship_outline.visible = true
		var th := art._thrust_now() if art != null else -2
		var win := art._arrive_window if art != null else -2
		var arriving := art != null and art._arrive_at >= 0
		var ol: bool = sc != null and sc._ship_outline != null and sc._ship_outline.visible
		var ph := int(sc._phase) if sc != null else -1
		out.store_line("%d\t%.2f\t%.3f\t%d\t%d\t%s\t%s\t%d\t%s" % [i, ms, GameClock.now(), th, win,
			arriving, ol, ph, ",".join(_events)])
		_events.clear()
		if i > 30 and ms > worst:
			worst = ms
			worst_at = i
	out.close()
	var sc2 := Router.current as SectorScreen
	if sc2 != null and sc2._view.ship_view() != null:
		var v := sc2._view.ship_view()
		print("arriveprobe: hull at rest %s, pointer %s" % [v.get_global_rect(), get_viewport().get_mouse_position()])
	print("arriveprobe: worst frame %.1f ms at %d" % [worst, worst_at])
	tree.quit()
