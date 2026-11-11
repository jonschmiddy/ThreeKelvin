extends Node

## Stills of LAUNCH A RUN at tiers 0 (no win), 3, 7, 8 and 10 (won up to there),
## the galaxy a second in, and tier 8 with the pointer on the galaxy (its tag of
## rules in force), for judging the box. `-- sheet=LaunchBoxShot out=<dir>`;
## needs a window. In its own scratch flight record and save.

var _out := ""


func _ready() -> void:
	_out = Harness.arg("out", "user://launchbox")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_run.call_deferred()


func _run() -> void:
	await Harness.frames(get_tree(), 2)
	DevMode.enabled = false
	RunHistory.path = TestRun.scratch("launchboxshot_history", "json")
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Rng.forced = 0
	SaveGame.save()
	Run.hull = null
	for pair: Array in [[0, -1], [3, 9], [7, 9], [8, 8], [10, 10]]:
		var tier: int = pair[0]
		var best: int = pair[1]
		var runs: Array = []
		if best >= 0:
			runs.append({"outcome": int(RunHistory.Outcome.WON), "chassis_manufacturer": "korvan", "ascension": best})
		var f := FileAccess.open(RunHistory.path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"version": RunHistory.VERSION, "runs": runs}))
		f.close()
		LaunchBox.last_tier = tier
		Router.show_launcher()
		await _secs(0.5)
		var nr := Harness.button_with_text(Router.current, "NEW RUN")
		nr.pressed.emit()
		await _secs(1.3)
		var img := get_tree().root.get_texture().get_image()
		img.save_png("%s/tier_%d.png" % [_out, tier])
		print("  wrote %s/tier_%d.png (%dx%d)" % [_out, tier, img.get_width(), img.get_height()])
		if tier == 8:
			await _hovered()
	SaveGame.clear()
	RunHistory.clear()
	print("launchboxshot: done")
	get_tree().quit()


## The pointer on the galaxy until the tag is up, then a still.
func _hovered() -> void:
	var box := Harness.first(Router.current, func(n: Node) -> bool: return n is LaunchBox) as LaunchBox
	var at := box.galaxy.get_global_rect().get_center() + Vector2(10, -6)
	get_tree().root.warp_mouse(at)
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	Input.parse_input_event(mm)
	await _secs(0.9)
	var img := get_tree().root.get_texture().get_image()
	img.save_png("%s/tier_8_hover.png" % _out)
	print("  wrote %s/tier_8_hover.png, tag up: %s" % [_out, TagLayer.instance != null and TagLayer.instance.shown() != null])
	get_tree().root.warp_mouse(Vector2(4, 4))
	var away := InputEventMouseMotion.new()
	away.position = Vector2(4, 4)
	away.global_position = away.position
	Input.parse_input_event(away)
	await _secs(0.4)


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout
