extends Node

## The front door's three berths for each manufacturer, nothing picked, so the
## stands' places can be laid side by side (Jon, Nov 12: "the stands don't line
## up between manufacturers"). `-- sheet=YardStandsShot out=<dir> [film=S]`;
## needs a window and developer mode (the editor binary) to open every banner.
## With `film=S` it holds Korvan's set S seconds for a `--write-movie` film.

var _out := ""


func _ready() -> void:
	_out = Harness.arg("out", "user://yardstands")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_run.call_deferred()


func _run() -> void:
	# `pin=S` holds the yard's clock, so two runs' stills differ only by what they change.
	if Harness.arg("pin", "") != "":
		YardScene.pin_clock = float(Harness.arg("pin", "6"))
	await Harness.frames(get_tree(), 2)
	if DevMode.available:
		DevMode.enabled = true
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
	for i in DB.STARTABLE.size():
		if not only.is_empty() and not String(DB.STARTABLE[i]) in only:
			continue
		cs._select(i)
		await _secs(1.2)
		_shot("%d_%s" % [i, DB.STARTABLE[i]])
		# `pick=medium` also shoots the set with that ship picked
		var pick := Harness.arg("pick", "")
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
