extends Node

## Stills of the banner shipyard as a player sees it, for judging the look:
## at rest, a ship picked, another pointed at (the blur), and a locked
## manufacturer's tarps. `-- sheet=YardFrontShot out=<dir>`; needs a window.
## `dev` opens every banner first, `nodev` shows a fresh profile's (from the
## editor binary, where developer mode is on). The window's own pixels.

var _out := ""


func _ready() -> void:
	_out = Harness.arg("out", "user://yardfront")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_run.call_deferred()


func _run() -> void:
	await Harness.frames(get_tree(), 2)
	if OS.get_cmdline_user_args().has("dev") and DevMode.available:
		DevMode.enabled = true
	if OS.get_cmdline_user_args().has("nodev"):
		DevMode.enabled = false
	Router.new_run(4242)
	await _secs(3.0)
	var cs := Router.current as ChassisSelect
	if cs == null:
		print("yardfrontshot: no hull pick")
		get_tree().quit(1)
		return
	_shot("1_rest")
	cs._pick_weight(HullData.Weight.MEDIUM)
	await _secs(1.0)
	_shot("2_picked")
	var heavy: YardStandSet = cs._yard.set_of(HullData.Weight.HEAVY)
	heavy.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await _secs(0.8)
	_shot("3_hover")
	heavy.notification(Control.NOTIFICATION_MOUSE_EXIT)
	await _secs(0.5)
	cs._select(DB.STARTABLE.find(&"solari"))
	await _secs(0.3)
	_shot("4_locked_drop")
	await _secs(2.5)
	_shot("5_locked")
	var light: YardStandSet = cs._yard.set_of(HullData.Weight.LIGHT)
	light.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await _secs(0.8)
	_shot("6_locked_hover")
	print("yardfrontshot: done, %s" % _out)
	get_tree().quit()


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	var img := get_tree().root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("  wrote %s/%s.png (%dx%d)" % [_out, name, img.get_width(), img.get_height()])
