extends Control
## Entry point. Builds the theme, the persistent HUD, and hands the content
## area to Router. Everything else is created in code by the screens.

func _ready() -> void:
	# Balance sim runs through the normal boot so the autoloads exist, then quits
	# before any UI is built:  godot --headless --path . -- sim runs=200
	if "sim" in OS.get_cmdline_user_args():
		HeadlessSim.new().run_sim()
		get_tree().quit()
		return

	theme = UITheme.build()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 12)
	var name_label := UITheme.body("THREE KELVIN", UITheme.ICE, UITheme.FS_HEAD)
	title.add_child(name_label)
	title.add_child(UITheme.body("chart coreward · your modules are your deck",
		UITheme.COLD, UITheme.FS_SMALL))
	root.add_child(title)

	var hud := HudBar.new()
	root.add_child(hud)

	var content := Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(content)

	Router.register(content, hud)
	Router.new_run()

var _menu: PauseMenu = null

## The game shipped with no way to exit — no quit action, no input map entries.
## Escape now opens the menu; F11 toggles fullscreen so a screen-sized window
## can never trap the player behind missing title-bar chrome again.
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_ESCAPE:
		toggle_menu()
	elif k.keycode == KEY_F11:
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)

## Opens the escape menu, or closes it if it is already up.
func toggle_menu() -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null
		return
	_menu = PauseMenu.new()
	add_child(_menu)
	_menu.setup()
	_menu.resume_requested.connect(toggle_menu)
	_menu.quit_requested.connect(get_tree().quit)
	_menu.new_run_requested.connect(func() -> void:
		toggle_menu()
		Router.new_run())
