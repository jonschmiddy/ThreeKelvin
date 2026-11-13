extends Node

## Stills of the front door at a held moment, to diff two builds pixel for pixel:
## the yard's clock pinned, every wait counted in frames (run with `--fixed-fps 60`).
## `-- sheet=YardPerfShot out=<dir> [nodev]`; needs a window.

var _out := ""


func _ready() -> void:
	_out = Harness.arg("out", "user://yardperfshot")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	tree.root.gui_disable_input = true
	await Harness.frames(tree, 2)
	DevMode.enabled = DevMode.available and not OS.get_cmdline_user_args().has("nodev")
	seed(7)
	YardScene.pin_clock = 6.0
	Router.new_run(4242)
	await Harness.frames(tree, 120)
	var cs := Router.current as ChassisSelect
	if cs == null:
		print("yardperfshot: no hull pick")
		tree.quit(1)
		return
	_shot("1_rest")
	cs._pick_weight(HullData.Weight.MEDIUM)
	await Harness.frames(tree, 60)
	_shot("2_picked")
	var heavy: YardStandSet = cs._yard.set_of(HullData.Weight.HEAVY)
	heavy.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await Harness.frames(tree, 60)
	_shot("3_hover")
	heavy.notification(Control.NOTIFICATION_MOUSE_EXIT)
	for i in [1, 6]:
		cs._select(i)
		await Harness.frames(tree, 150)
		_shot("4_%s" % DB.STARTABLE[i])
	print("yardperfshot: done, %s" % _out)
	tree.quit()


func _shot(name: String) -> void:
	var img := get_tree().root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("  wrote %s/%s.png" % [_out, name])
