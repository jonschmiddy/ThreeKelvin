extends Node

## There is no tour now (tutorial direction B, Oct 17); this films the opening and goal line.
## Why: docs/why/IntroShot.md#intro-shot

var _args: PackedStringArray


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
	if "reduced" in _args:
		DisplaySettings.reduced_motion = true
	# a fresh player, as far as the scratch store knows
	Hints.reset()
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	var dir := _arg("clip")
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	var every := int(_arg("every", "6"))
	var frames := int(float(_arg("secs", "12")) * 60.0)
	var t := 0.0
	var k := 0
	var control_at := -1.0
	for i in frames:
		await RenderingServer.frame_post_draw
		t += get_process_delta_time()
		if dir != "" and i % every == 0:
			tree.root.get_texture().get_image().save_png("%s/f_%04d.png" % [dir, k])
			k += 1
		var sc := Router.current as SectorScreen
		if control_at < 0.0 and sc != null and sc.cutaway_ready():
			control_at = t
			var g: GoalLine = Router.hud.goal
			print("introshot: control at %.2f s (game clock), goal line %s, step \"%s\"" % [
				t, "up" if g != null and g.visible else "not up", g._step.text if g != null else ""])
	var cur := Router.current
	print("introshot: on %s, control %s" % [
		cur.get_script().get_global_name() if cur != null else "nothing",
		("at %.2f s" % control_at) if control_at >= 0.0 else "never"])
	tree.quit()
