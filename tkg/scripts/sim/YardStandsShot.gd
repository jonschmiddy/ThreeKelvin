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
	YardInfo.hold_open = OS.get_cmdline_user_args().has("deckopen")
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


## Where each berth's posts stand and how tall, as the rule placed them.
func _shadows(y: YardFront) -> void:
	for w: HullData.Weight in y.sets:
		var s: YardStandSet = y.sets[w]
		print("  posts %-6s at %s top %d feet %d, guns %s" % [HullData.weight_name(w), s.post_x, s.post_top, s.feet, s.guns])