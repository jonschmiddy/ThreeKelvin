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

	# Save/load round-trip test, same shape as the balance sim above it:
	#   godot --headless --path . -- savetest
	if "savetest" in OS.get_cmdline_user_args():
		var t: RefCounted = load("res://scripts/sim/SaveTest.gd").new()
		t.run()
		t.run_history_test()
		get_tree().quit()
		return

	DisplaySettings.load_and_apply()
	theme = UITheme.build()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 5)
	margin.add_child(root)

	var hud := HudBar.new()
	root.add_child(hud)

	var content := Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(content)

	Router.register(content, hud)

	# Boot destination. The launcher is the default, and every development flag
	# below skips it — an automated run must never stop at a screen waiting to
	# be clicked, and a flag that drops you into a fight plainly means "not the
	# title screen" without having to say so.
	#
	#   -- nolauncher   straight into a new run
	#   -- resume       straight into the suspend save, if there is one
	var argv := OS.get_cmdline_user_args()
	var skip_launcher := "nolauncher" in argv or "cards" in argv or "fight" in argv \
		or "charttest" in argv
	if "resume" in argv and SaveGame.has_save():
		Router.continue_run()
	elif skip_launcher:
		Router.new_run()
	else:
		Router.show_launcher()

	# Dev shortcut: drop straight into a fight with a hand of cards.
	#   godot --path . -- fight
	# Card work is 90% of what gets iterated on and reaching a fight normally
	# costs a jump, a sector screen and a loading pass every time you change a
	# pixel. Deliberately not a menu item — it skips the run the balance depends
	# on, so it stays a flag you have to type.
	# Star chart cache test. Needs the real shell and a window, so unlike the
	# sim and savetest it runs after boot rather than instead of it:
	#   godot --path . -- charttest
	if "charttest" in OS.get_cmdline_user_args():
		# Held in a member, not called on a throwaway. ChartTest.run() awaits,
		# and a RefCounted nothing holds a reference to is freed the moment the
		# calling statement ends — the suspended coroutine goes with it and the
		# test dies silently after its first print. SaveTest gets away with
		# `load(...).new().run()` only because it never awaits.
		_chart_test = load("res://scripts/sim/ChartTest.gd").new()
		_chart_test.run(get_tree())
	if "cards" in OS.get_cmdline_user_args():
		Router.show_cards()
	elif "fight" in OS.get_cmdline_user_args():
		# `-- fight 10` deals ten. The hand is the one layout that only
		# misbehaves at sizes a normal run rarely reaches, so seeing it full
		# should not require finding a Redline set bonus first.
		for a in OS.get_cmdline_user_args():
			if a.is_valid_int():
				Run.hand_size_override = clampi(int(a), 1, 12)
		var pool := DB.fight_pool(3, false)
		Router.start_combat(DB.enemies[pool.pick_random()])

## Kept alive for the duration of `-- charttest`; see the call site.
var _chart_test: RefCounted = null

var _menu: PauseMenu = null
var _settings: SettingsMenu = null

## The game shipped with no way to exit — no quit action, no input map entries.
## Escape now opens the menu; F11 toggles fullscreen so a screen-sized window
## can never trap the player behind missing title-bar chrome again.
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_ESCAPE:
		if _settings != null:
			_close_settings()
		elif Router.current is LauncherScreen:
			pass   ## nothing to pause: the launcher IS the menu
		else:
			toggle_menu()
	elif k.keycode == KEY_F11:
		DisplaySettings.toggle_fullscreen()

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
	_menu.quit_requested.connect(func() -> void:
		SaveGame.clear()
		get_tree().quit())
	_menu.new_run_requested.connect(func() -> void:
		toggle_menu()
		Router.new_run())
	_menu.settings_requested.connect(_open_settings)
	# The autosave has already written a screen swap, but state moves after one
	# — a station's purchases and repairs all land on a screen that was saved
	# when it opened — so the explicit write is what makes SAVE & QUIT mean it.
	#
	# Not mid-combat, though. Combat is outside the save by design and the format
	# stores none of it, so writing there banked the hull and heat the fight had
	# already spent against an enemy that comes back at full HP on a node still
	# marked unfought: strictly worse than force-quitting, from the button that
	# promises to be the safe way out. Mid-fight this now does what force-quitting
	# does — the last save, from before the shooting started, stands.
	_menu.save_and_quit_requested.connect(func() -> void:
		if not Router.in_combat():
			SaveGame.save()
		get_tree().quit())

func _open_settings() -> void:
	if _settings != null:
		return
	_settings = SettingsMenu.new()
	add_child(_settings)
	_settings.setup()
	_settings.closed.connect(_close_settings)

func _close_settings() -> void:
	if _settings == null:
		return
	_settings.queue_free()
	_settings = null
