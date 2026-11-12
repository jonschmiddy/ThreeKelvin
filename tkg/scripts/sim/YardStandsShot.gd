extends Node

## The front door's berths, each set with nothing picked (Jon, Nov 12), for stills
## side by side, and the light under each hull. `out=<dir> [film=S] [pin=S]
## [only=korvan,solari] [pick=medium] [dev=0]`; needs a window. docs/tests.md has more.

var _out := ""


func _ready() -> void:
	_out = Harness.arg("out", "user://yardstands")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_run.call_deferred()


func _run() -> void:
	if Harness.arg("pin", "") != "":
		YardScene.pin_clock = float(Harness.arg("pin", "6"))
	await Harness.frames(get_tree(), 2)
	# `dev=0` keeps developer mode off: one open banner, the rest locked
	if DevMode.available:
		DevMode.enabled = Harness.arg("dev", "1") != "0"
	Router.new_run(4242)
	await _secs(3.0)
	var cs := Router.current as ChassisSelect
	if cs == null:
		print("yardstandsshot: no hull pick")
		get_tree().quit(1)
		return
	var film := float(Harness.arg("film", "0"))
	if film > 0.0:
		await _secs(film)
		print("yardstandsshot: filmed %.1f s" % film)
		get_tree().quit()
		return
	var only := Harness.arg("only", "").split(",", false)
	var pick := Harness.arg("pick", "")
	for i in DB.STARTABLE.size():
		if not only.is_empty() and not String(DB.STARTABLE[i]) in only:
			continue
		cs._select(i)
		await _secs(1.2)
		_shot("%d_%s" % [i, DB.STARTABLE[i]])
		_shadows(cs._yard)
		if pick != "":
			cs._pick_weight({"light": HullData.Weight.LIGHT, "medium": HullData.Weight.MEDIUM, "heavy": HullData.Weight.HEAVY}[pick])
			await _secs(1.2)
			_shot("%d_%s_picked" % [i, DB.STARTABLE[i]])
			cs._picked = -1
			cs._yard.set_picked(-1)
			cs._show_band()
	print("yardstandsshot: done, %s" % _out)
	get_tree().quit()


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	var img := get_tree().root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("  wrote %s/%s.png (%dx%d)" % [_out, name, img.get_width(), img.get_height()])


## The floor lamps' light under each hull against beside its berth: the hulls'
## shadows in the pools, measured off the baked pools.
func _shadows(y: YardFront) -> void:
	var L := y.scene.light
	for w: HullData.Weight in y.sets:
		var s: YardStandSet = y.sets[w]
		var f := s.feet - 6
		var under := 0.0
		var beside := 0.0
		for dx in range(-20, 21, 4):
			under += L.bay_at(s.thing.position.x + s.thing.size.x / 2 + dx, f)
			beside += maxf(L.bay_at(s.thing.position.x - 70 + dx, f), L.bay_at(s.thing.end.x + 70 + dx, f))
		print("  pools %-6s under the hull %.2f, beside the berth %.2f" % [HullData.weight_name(w), under / 11.0, beside / 11.0])
