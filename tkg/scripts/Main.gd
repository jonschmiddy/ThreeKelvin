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

	# The whole price table, and the proof that it cannot be gamed:
	#   godot --headless --path . -- market
	# Same shape as savetest above it, and for the same reason: the thing it
	# checks fails silently. A market whose melt price creeps above its ask price
	# does not crash, it just quietly pays for the rest of the run.
	if "market" in OS.get_cmdline_user_args():
		load("res://scripts/sim/MarketTest.gd").new().run()
		get_tree().quit()
		return

	# Every starting chassis and what it reads on the six attributes:
	#   godot --headless --path . -- attrs
	# Attribute constants are tuned by staring at this table, and the numbers are
	# only meaningful against each other — a column at a time, not a ship at a
	# time. Reading them off a UI one manufacturer per screen is how you convince
	# yourself a spread exists that does not.
	if "attrs" in OS.get_cmdline_user_args():
		_print_attribute_table()
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
	#
	# `ship` belongs in this list and its absence is not cosmetic: the refit
	# screen reads Run.hull, which is null until a run starts, so booting to the
	# launcher and then swapping the ship screen over it crashes on arrival.
	var argv := OS.get_cmdline_user_args()
	var skip_launcher := "nolauncher" in argv or "cards" in argv or "fight" in argv \
		or "charttest" in argv or "ship" in argv or "station" in argv
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
	elif "ship" in OS.get_cmdline_user_args():
		# The refit screen normally sits two clicks and a chassis choice away,
		# and it is where the attribute block lives — so the screen that most
		# needs looking at was the most tedious to reach.
		Router.show_ship()
	elif "station" in OS.get_cmdline_user_args():
		# The dock, immediately. Added when the station became four panels rather
		# than two — a shelf, a service desk, a buyer for the hold and a
		# fabricator — and reaching it normally costs a chassis choice, a jump
		# and a sector screen every time one of those four moves a pixel.
		#
		# It also gives the merge gate something that CONSTRUCTS the screen. The
		# boot check only ever built the launcher, so the busiest screen in the
		# game was the one nothing automated had ever drawn.
		var here: MapGen.MapNode = Run.node_at()
		here.type = MapGen.NodeType.STATION
		here.development = MapGen.Development.CITY
		here.security = 4
		here.makers = [&"solari", &"cygnet"]
		here.manufacturer = &"solari"
		here.danger = 5
		# Something in the hold to sell, something to melt, and enough of every
		# material to light up the fabricator and the material rows.
		for i in 3:
			Run.cargo.append(LootGen.roll_module(4 + i, &"", true))
		Run.add_material(&"alloy", 6)
		Run.add_material(&"exotic", 2)
		Run.add_material(&"relic", 1)
		Run.hp = maxi(1, Run.max_hp() - 12)
		Run.dross = 1
		Router.show_station()
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

## Starts a run per manufacturer and prints the resulting attribute row, plus
## the raw gauges each one is derived from so a surprising attribute can be
## traced to the stat that caused it without opening Database.gd.
func _print_attribute_table() -> void:
	print("chassis            HUL THR MNV THM SEN STL   hp/cap/diss/dodge/init/fuel  mounts  kit set")
	for man in DB.STARTABLE:
		for w in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
			Run.start_new_run(man, int(w))
			var row := ""
			for a in Run.attributes():
				row += "%3d " % int(a.value)
			print("%-18s %s  %3d/%3d/%3d/%.2f/%+d/%.1f   %d/%d/%d    %d  %s %d" % [
				Run.hull.name, row, Run.hp, Run.heat_cap(), Run.dissipation(),
				Run.hull.dodge, Run.hull.initiative, Run.hull.fuel_factor,
				Run.hull.weapon_slots, Run.hull.system_slots, Run.hull.utility_slots,
				Run.installed.size(),
				DB.short_name(DB.manufacturer_name(man)), Run.manufacturer_count(man)])
		print("")
	print("\nunbranded salvage frames, at full hull:")
	for h in DB.hull_frames:
		if h.manufacturer != &"":
			continue
		Run.hull = h.duplicate(true) as HullData
		Run.installed.clear()
		Run.hp = Run.max_hp()
		var row2 := ""
		for a in Run.attributes():
			row2 += "%3d " % int(a.value)
		print("%-18s %s" % [h.name, row2])

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
