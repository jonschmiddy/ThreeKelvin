extends Node

## A.S.H. BESIDE THE GOAL LINE AT A RUN'S START, as the game draws it:
##   godot --path . --windowed --resolution 1920x1080 -- sheet=AshGoalShot ash hints out=<dir> [intro=0|1]
##
## A new run on LOCAL with her and the hints on (fresh hints; `intro=1`, the
## default, a profile that has not heard her introduction, `intro=0` one that
## has), each of her lines photographed as it holds (`local_<n>_<kind>.png`),
## then the chart (`chart.png`) and the sector map (`map.png`) with the goal and
## its step up. Each still is the whole window and a 2x crop of its top left
## (`_tl.png`, the first 480x270 game pixels). Prints every line she said, with
## her box, the goal's and the step's. Needs a window.

var _args: PackedStringArray
var _out := ""


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _secs(s: float) -> void:
	var t0 := GameClock.now()
	while GameClock.now() - t0 < s:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	var k := float(img.get_width()) / 960.0
	var tl := img.get_region(Rect2i(0, 0, int(480.0 * k), int(270.0 * k)))
	tl.resize(960, 540, Image.INTERPOLATE_NEAREST)
	tl.save_png("%s/%s_tl.png" % [_out, name])
	var g: GoalLine = Router.hud.goal if Router.hud != null else null
	print("[ashgoalshot] %s: her box %s, goal %s, step %s" % [name,
		Ash.portrait.rect() if Ash.portrait != null and Ash.portrait.visible else Rect2(),
		g.rect() if g != null else Rect2(), g.step_rect() if g != null else Rect2()])


func _run() -> void:
	var tree := get_tree()
	_out = _arg("out", "user://ashgoalshot")
	DirAccess.make_dir_recursive_absolute(_out)
	await tree.process_frame
	Ash.forced = true
	Ash.reload()
	Ash.set_on(true)
	Hints.forced = true
	Hints.reset()
	var cfg := ConfigFile.new()
	cfg.load(DisplaySettings.hints_path())
	cfg.set_value("hints", "ash_intro", _arg("intro", "1") != "1")
	cfg.save(DisplaySettings.hints_path())
	Ash.reload()
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	# her lines as they come, each photographed once it holds
	var n0 := Ash.said_log.size()
	var shot := n0
	var t0 := GameClock.now()
	while GameClock.now() - t0 < 30.0 and shot < n0 + 3:
		await tree.process_frame
		var p := Ash.portrait
		if Ash.said_log.size() > shot and p != null and p.phase == AshPortrait.Phase.HOLDING:
			var d: Dictionary = Ash.said_log[shot]
			print("[ashgoalshot] line %d: %s \"%s\"" % [shot - n0, d.kind, d.line])
			await _shot("local_%d_%s" % [shot - n0, d.kind])
			shot += 1
	for d: Dictionary in Ash.said_log.slice(n0):
		print("[ashgoalshot] said at %.2f: %s" % [d.at, d.kind])
	if Ash.portrait != null:
		Ash.portrait.cut()
	Router.show_starchart()
	await _secs(3.0)
	await _shot("chart")
	Router.show_system()
	await _secs(3.0)
	await _shot("map")
	Ash.forced = false
	Hints.forced = false
	tree.quit(0)
