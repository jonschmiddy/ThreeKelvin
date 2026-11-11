extends Node

## The star chart's own galaxy, small, for each tier's picture on LAUNCH A RUN: a run at the
## tier in one of its galaxy kinds, the real star chart with its icons off, one still of the
## sky for each step of a whole turn (`frame_<t>_<k>.png`), for tools/dev/tier_minis.py to
## pixelate. `-- sheet=TierMiniBake out=<dir> [tiers=0,5,10] [limit=N] [tornsweep=1]`; needs a window.

## Seconds a whole turn takes at tier 0 and at tier 10; frames a second of the picture.
const TURN_S := [24.0, 8.0]
const FPS := 12
## The chart's zoom for the shot: the whole galaxy in the frame (ChartLook's "opening" is 0.42).
const VIEW_Z := 0.28
const TORN_LOST := 4.0

var _out := ""


func _ready() -> void:
	_out = Harness.arg("out", "user://tierminis")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	get_viewport().gui_disable_input = true
	_run.call_deferred()


## Frames in tier t's loop: one whole turn, quicker up the ladder.
static func frames_of(t: int) -> int:
	return int(round(lerpf(TURN_S[0], TURN_S[1], float(t) / 10.0) * FPS))


## Tier t's galaxy kind: its form's kinds in turn, so the rungs of one form differ.
static func kind_of(t: int) -> int:
	var ks := Ladder.kinds_of(t)
	var first := t
	while first > 0 and Ladder.form(first - 1) == Ladder.form(t):
		first -= 1
	return ks[(t - first) % ks.size()]


func _run() -> void:
	await Harness.frames(get_tree(), 2)
	DevMode.enabled = false
	for ts in Harness.arg("tiers", "0,1,2,3,4,5,6,7,8,9,10").split(","):
		await _bake(int(ts))
	print("tierminibake: done")
	get_tree().quit()


func _bake(t: int) -> void:
	Rng.forced = 4242
	Run.forced_ascension = t
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.forced_ascension = -1
	Rng.forced = 0
	Run.galaxy_kind = kind_of(t)
	Run.galaxy = GalaxyGen.roll(Run.galaxy_kind)
	Run.map = MapGen.generate(Run.MAP_CANVAS)
	Run.at = 0
	Run.trail = PackedInt32Array([0])
	Run._range_cache.clear()
	Run.chart_from(Run.node_at())
	# tier 10: the dwarf shown with its outer rings already torn away (TORN AWAY from jump 4)
	ChartTorn.active = t == 10
	ChartTorn.lost = TORN_LOST if t == 10 else 0.0
	Router.show_starchart()
	var scp := Router.current as StarchartScreen
	var ch := scp._chart
	var t0 := Time.get_ticks_msec()
	while not (ch._sky as ChartSky).ready_to_draw() and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().process_frame
	scp.dismiss_primer()
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.turn_speed = 0.0
	var k0: float = ch._radius() * MapChart.DISC
	ch._go_to(VIEW_Z * ChartSky.K0 / k0, Vector2.ZERO, false)
	for _i in 30:
		await get_tree().process_frame
	if t == 0:
		await _shot(ch, "chart_%d" % t)
	ch.show_icons = false
	var n := frames_of(t) if Harness.arg("limit") == "" else int(Harness.arg("limit"))
	print("  tier %d: %s (kind %d), %d frames" % [t, GalaxyGen.type_name(Run.galaxy_kind), Run.galaxy_kind, n])
	for k in n:
		ch.sky_angle = TAU * float(k) / float(n)
		# `tornsweep=1`: tier 10's rings fall one by one over the turn, back whole at the loop
		if t == 10 and Harness.arg("tornsweep") == "1":
			ChartTorn.lost = ChartTorn.max_lost() * float(k) / float(n)
		ch._repaint_galaxy()
		ch._repaint_sky()
		await _shot(ch, "frame_%d_%d" % [t, k])
	ch.show_icons = true


func _shot(ch: MapChart, name: String) -> void:
	for _i in 4:
		await RenderingServer.frame_post_draw
	var img := ch.get_viewport().get_texture().get_image()
	var at := ch.get_global_transform_with_canvas().origin
	img.get_region(Rect2i(Vector2i(at.round()), Vector2i(ch.size.round()))).save_png("%s/%s.png" % [_out, name])
