extends Harness

## The escape menu after the motion settings change under it:
##   godot --headless --path . -- menutest
##
## Jon: "Clicking reduced motion and/or clicking skip animations makes the
## escape menu lock up?" It did, on one path. A menu opened UNDER reduced motion
## never set its backdrop's `amount`, because only the animated way in set it.
## Turn reduced motion off in Settings and the way out is animated again, and
## `close` read that `amount`: null, `as float` threw, and `close` stopped
## halfway. Main had already let go of the menu, so it stayed up, swallowing
## every click, and Escape opened a second one over it.
##
## HEADLESS NEVER ANIMATES (`Router.animating`), which is why no test saw it.
## This one turns the animations on with `Router.animate_in_harness`, so the
## tweens and the animated close really run.
##
## Each case opens the menu with Escape, goes into Settings by its button,
## changes the motion settings, and then checks the menu still answers: Escape
## leaves Settings, BACK leaves Settings, Escape shuts the menu and it is GONE
## from the tree, and the ship screen takes its keys again. The settings are
## changed in memory and the panel redrawn, as the chip does, without the save:
## the player's settings file is never written.

var _tree: SceneTree
var _main: Node
var _ship: ShipScreen

const CASES := [
	{"name": "reduced motion turned on", "open": [false, false], "set": [true, false]},
	{"name": "skip jump turned on", "open": [false, false], "set": [false, true]},
	{"name": "both turned on", "open": [false, false], "set": [true, true]},
	{"name": "reduced motion turned off, menu opened under it", "open": [true, false], "set": [false, false]},
	{"name": "both turned off, menu opened under them", "open": [true, true], "set": [false, false]},
]


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame
	var was_reduced := DisplaySettings.reduced_motion
	var was_skip := DisplaySettings.skip_jump
	Router.animate_in_harness = true
	_main = first(tree.root, func(n: Node) -> bool:
		return n.has_method("toggle_menu") and n.has_method("_open_settings"))
	if _ok("Main is up", _main != null):
		seed_run(4471)
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		Router.show_ship()
		if _ok("the ship screen is up", await _wait_for(func() -> bool:
				return Router.current is ShipScreen)):
			_ship = Router.current as ShipScreen
			await _secs(0.3)
			for c: Dictionary in CASES:
				print(c.name)
				await _pause_case(c)
			print("the title-style Settings drawer, reduced motion turned off")
			await _drawer_case()
			print("the rendering style")
			await _style_case()
			print("graphics LOW")
			await _graphics_case()
			print("TUTORIAL ON / OFF")
			await _tutorial_case()
			print("SAVE MY LOGS")
			await _logs_case()
			print("the first launch's window")
			await _first_window_case()
			print("a Retina Mac's window stops at 2X")
			await _retina_case()
			print("MOTION in dev mode: the player's rows only")
			await _dev_motion_case()
			print("RUN ENDED: TITLE")
			await _run_ended_case()
			print("Esc on the hull pick")
			await _chassis_case()
	DisplaySettings.reduced_motion = was_reduced
	DisplaySettings.skip_jump = was_skip
	Router.animate_in_harness = false
	await _finish()


func _pause_case(c: Dictionary) -> void:
	_set_motion(c.open)
	await _press(KEY_ESCAPE)
	await _secs(0.4)
	var menu: PauseMenu = _main.get("_menu")
	if not _ok("  Escape opens the menu", menu != null):
		return
	_plate(menu, "SETTINGS").pressed.emit()
	await _secs(0.3)
	if not _ok("  its SETTINGS button opens Settings", menu.in_settings()):
		return

	_set_motion(c.set)
	(menu._settings as SettingsPanel)._refresh()
	await _secs(0.2)

	await _press(KEY_ESCAPE)
	await _secs(0.3)
	_ok("  Escape leaves Settings", not menu.in_settings())
	_ok("  and the menu is back, visible", menu._main.visible and menu._main.modulate.a > 0.99)

	_plate(menu, "SETTINGS").pressed.emit()
	await _secs(0.3)
	_plate(menu._settings, "BACK").pressed.emit()
	await _secs(0.3)
	_ok("  BACK leaves Settings too", not menu.in_settings())

	await _press(KEY_ESCAPE)
	await _secs(0.5)
	_ok("  Escape shuts the menu", _main.get("_menu") == null)
	_ok("  and it is gone from the screen, not left up swallowing clicks",
		not is_instance_valid(menu) and _pause_menus() == 0)

	var zoomed := _ship._zoomed
	await _press(KEY_Z)
	_ok("  the game answers its keys again (Z zooms the ship)", _ship._zoomed != zoomed)
	await _press(KEY_Z)


## The drawer the title screen uses (SettingsMenu), opened over the run by
## Main and shut by its BACK: the same backdrop and the same close.
func _drawer_case() -> void:
	_set_motion([true, false])
	_main.call("_open_settings")
	await _secs(0.3)
	var drawer: SettingsMenu = _main.get("_settings")
	if not _ok("  the drawer opens", drawer != null):
		return
	_set_motion([false, false])
	var panel := first(drawer, func(n: Node) -> bool: return n is SettingsPanel) as SettingsPanel
	panel._refresh()
	await _secs(0.2)
	_plate(drawer, "BACK").pressed.emit()
	await _secs(0.5)
	_ok("  BACK shuts it and it is gone",
		_main.get("_settings") == null and not is_instance_valid(drawer))


## THE RENDERING STYLE (`DisplaySettings.render_style`): SIMPLIFIED by default,
## a style with no renderer cannot be chosen, a settings file naming one that is
## unknown or not built loads as the default, the choice survives a save and a load,
## and while only one style is built Settings builds no STYLE row at all. In a
## scratch settings file: the player's is never read or written.
func _style_case() -> void:
	const SCRATCH := "user://styletest_settings.cfg"
	var was_path := DisplaySettings.path
	var was_style := DisplaySettings.render_style
	DisplaySettings.path = SCRATCH
	var fresh := ConfigFile.new()
	_ok("  a fresh settings file is SIMPLIFIED", DisplaySettings.style_in(fresh) == &"simplified")
	_ok("  SIMPLIFIED is built, LEGACY first in the list", DisplaySettings.style_built(&"simplified")
		and DisplaySettings.STYLES[0] == &"legacy" and DisplaySettings.STYLES[1] == &"simplified")
	var heard := [0]
	var on_change := func() -> void: heard[0] += 1
	Sig.render_style_changed.connect(on_change)
	for s: StringName in DisplaySettings.STYLES:
		if not DisplaySettings.style_built(s):
			var before := DisplaySettings.render_style
			_ok("  %s, not built, cannot be chosen" % s,
				not DisplaySettings.set_render_style(s) and DisplaySettings.render_style == before)
	_ok("  and choosing one said nothing", heard[0] == 0)
	Sig.render_style_changed.disconnect(on_change)
	for bad in ["sparkly", "legacy", "painted", "radiant", "", 7]:
		if DisplaySettings.style_built(StringName(str(bad))):
			continue
		var cfg := ConfigFile.new()
		cfg.set_value("display", "render_style", bad)
		cfg.save(SCRATCH)
		var back := ConfigFile.new()
		back.load(SCRATCH)
		_ok("  a saved %s loads as the default" % [JSON.stringify(bad)], DisplaySettings.style_in(back) == DisplaySettings.DEFAULT_STYLE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	DisplaySettings.render_style = &"simplified"
	DisplaySettings.save()
	var saved := ConfigFile.new()
	_ok("  SIMPLIFIED is saved and read back", saved.load(SCRATCH) == OK
		and str(saved.get_value("display", "render_style", "")) == "simplified"
		and DisplaySettings.style_in(saved) == &"simplified")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	DisplaySettings.path = was_path
	DisplaySettings.render_style = was_style
	# no STYLE row while there is only one style to choose
	var panel := SettingsPanel.new()
	_tree.root.add_child(panel)
	panel.build()
	await _tree.process_frame
	var row := first(panel, func(n: Node) -> bool:
		return n is Label and (n as Label).text == "STYLE")
	if DisplaySettings.built_styles().size() > 1:
		_ok("  Settings shows a STYLE row (%d styles built)" % DisplaySettings.built_styles().size(), row != null)
	else:
		_ok("  Settings builds no STYLE row with one style built", row == null)
	panel.queue_free()
	await _tree.process_frame


## GRAPHICS LOW from Settings (`DisplaySettings.set_graphics_low`): the row is
## there beside STYLE, a press keeps it (written to a scratch settings file,
## never the player's), the sky is told to rebuild, and turning it on lets
## RADIANT's safety try again.
func _graphics_case() -> void:
	const SCRATCH := "user://gfxtest_settings.cfg"
	var was_path := DisplaySettings.path
	var was_low := DisplaySettings.graphics_low
	var was_fell := ChartRadiant.fell_back
	DisplaySettings.path = SCRATCH
	var panel := SettingsPanel.new()
	_tree.root.add_child(panel)
	panel.build()
	await _tree.process_frame
	var row := first(panel, func(n: Node) -> bool:
		return n is Label and (n as Label).text == "GRAPHICS")
	_ok("  Settings shows a GRAPHICS row", row != null)
	var low_chip := first(panel, func(n: Node) -> bool:
		return n is DrawerPlate and (n as DrawerPlate).title == "LOW") as DrawerPlate
	_ok("  with a LOW chip that says what it does", low_chip != null and low_chip.tooltip_text != "")
	var heard := [0]
	var on_change := func() -> void: heard[0] += 1
	Sig.render_style_changed.connect(on_change)
	DisplaySettings.graphics_low = false
	ChartRadiant.fell_back = true
	if low_chip != null:
		low_chip.pressed.emit()
	await _tree.process_frame
	Sig.render_style_changed.disconnect(on_change)
	var saved := ConfigFile.new()
	_ok("  pressing LOW turns it on", DisplaySettings.graphics_low)
	_ok("  and keeps it, in the scratch file", saved.load(SCRATCH) == OK
		and bool(saved.get_value("display", "graphics_low", false)))
	_ok("  and the sky is told to rebuild", heard[0] >= 1)
	_ok("  and RADIANT's safety may try again on LOW", not ChartRadiant.fell_back)
	panel.queue_free()
	await _tree.process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	DisplaySettings.path = was_path
	DisplaySettings.graphics_low = was_low
	ChartRadiant.fell_back = was_fell


## TUTORIAL ON / OFF (Jon, Oct 20: "Have a setting in the options for tutorial
## on or tutorial off"): the row is in Settings' HINTS with ON picked on a fresh
## file, OFF is kept and read back (written to a scratch settings file, never
## the player's), ON brings it back; and pressing REPLAY TUTORIAL does not move
## it (nothing clickable moves).
func _tutorial_case() -> void:
	const SCRATCH := "user://tuttest_settings.cfg"
	var was_path := DisplaySettings.path
	var was_on := Hints.tutorial_on()
	DisplaySettings.path = SCRATCH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	Hints._tutorial_read = false
	var panel := SettingsPanel.new()
	_tree.root.add_child(panel)
	panel.build()
	await _tree.process_frame
	var chips := _tutorial_chips(panel)
	_ok("  Settings shows a TUTORIAL row with ON and OFF", chips.size() == 2 and chips[0].title == "ON" and chips[1].title == "OFF")
	_ok("  ON on a fresh settings file", Hints.tutorial_on() and chips.size() == 2 and chips[0].lead and not chips[1].lead)
	if chips.size() == 2:
		var at0: Rect2 = (chips[1] as Control).get_global_rect()
		chips[1].pressed.emit()
		await _tree.process_frame
		var saved := ConfigFile.new()
		_ok("  pressing OFF turns it off", not Hints.tutorial_on())
		_ok("  and keeps it, in the scratch file", saved.load(SCRATCH) == OK
			and not bool(saved.get_value("hints", "tutorial", true)))
		Hints._tutorial_read = false
		_ok("  and it is read back off", not Hints.tutorial_on())
		# REPLAY TUTORIAL adds a line under itself: the TUTORIAL row stays put
		var again := _plate(panel, "REPLAY TUTORIAL")
		if again != null:
			again.pressed.emit()
			await _tree.process_frame
		var chips2 := _tutorial_chips(panel)
		_ok("  REPLAY TUTORIAL does not move it (%s, was %s)" % [chips2[1].get_global_rect() if chips2.size() == 2 else Rect2(), at0],
			chips2.size() == 2 and chips2[1].get_global_rect() == at0)
		if chips2.size() == 2:
			chips2[0].pressed.emit()
			await _tree.process_frame
		_ok("  pressing ON turns it back on", Hints.tutorial_on())
	panel.queue_free()
	await _tree.process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	DisplaySettings.path = was_path
	Hints._tutorial_read = false
	if Hints.tutorial_on() != was_on:
		Hints.set_tutorial(was_on)


## The TUTORIAL row's chips, ON then OFF.
func _tutorial_chips(panel: Node) -> Array:
	var lab := first(panel, func(n: Node) -> bool:
		return n is Label and (n as Label).text == "TUTORIAL")
	if lab == null:
		return []
	var out: Array = []
	for n in lab.get_parent().find_children("*", "DrawerPlate", true, false):
		out.append(n)
	return out


## SAVE MY LOGS (`PlaytestLogs`): the button is in Settings, and the zip it
## writes holds the named files and nothing else -- written to a scratch folder,
## not the Desktop, with a scratch settings file; then removed.
func _logs_case() -> void:
	const SCRATCH := "user://logstest_settings.cfg"
	var was_path := DisplaySettings.path
	DisplaySettings.path = SCRATCH
	DisplaySettings.save()
	var panel := SettingsPanel.new()
	_tree.root.add_child(panel)
	panel.build()
	await _tree.process_frame
	_ok("  Settings has SAVE MY LOGS", _plate(panel, "SAVE MY LOGS") != null)
	panel.queue_free()
	var dest := ProjectSettings.globalize_path("user://logstest")
	PlaytestLogs.dest_override = dest
	var r := PlaytestLogs.save_bundle()
	PlaytestLogs.dest_override = ""
	if _ok("  it writes a zip", r.get("ok", false) and FileAccess.file_exists(String(r.path))):
		var zr := ZIPReader.new()
		zr.open(String(r.path))
		var names := zr.get_files()
		var allowed := ["settings.cfg", "run.save", "history.json", "build.txt"]
		var stray := []
		for n in names:
			# (the logs folder's own entry, which the packer writes for a nested name)
			if not (n in allowed or n == "logs/" or (n.begins_with("logs/") and n.ends_with(".log"))):
				stray.append(n)
		_ok("  holding godot.log, the settings and the build", "logs/godot.log" in names
			and "settings.cfg" in names and "build.txt" in names)
		_ok("  and nothing else (%s)" % ", ".join(names), stray.is_empty())
		var log := zr.read_file("logs/godot.log").get_string_from_utf8()
		var home := OS.get_environment("USERPROFILE")
		if home == "":
			home = OS.get_environment("HOME")
		_ok("  with the home folder taken out of the log", home == "" or not log.contains(home.replace("\\", "/")))
		_ok("  and the build named", zr.read_file("build.txt").get_string_from_utf8().begins_with("Three Kelvin"))
		zr.close()
		DirAccess.remove_absolute(String(r.path))
	DirAccess.remove_absolute(dest)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	DisplaySettings.path = was_path
	await _tree.process_frame


## THE FIRST LAUNCH'S WINDOW (`DisplaySettings.first_launch_window`; Jon's
## release-check pick A, Oct 18). With no settings file: BORDERLESS where a
## window could only be 1x (a 1080p screen), else a window at the largest size
## that fits. A settings file that exists is never overridden. Through the real
## `load_and_apply`, on a scratch file.
func _first_window_case() -> void:
	const SCRATCH := "user://firstwindow_settings.cfg"
	var was_path := DisplaySettings.path
	var was_mode := DisplaySettings.mode
	var was_scale := DisplaySettings.window_scale
	DisplaySettings.first_launch_window(1)
	_ok("  a screen that fits only 1x starts BORDERLESS", DisplaySettings.mode == DisplaySettings.Mode.BORDERLESS)
	DisplaySettings.first_launch_window(2)
	_ok("  one that fits 2x starts in a 2x window", DisplaySettings.mode == DisplaySettings.Mode.WINDOWED
		and DisplaySettings.window_scale == 2)
	DisplaySettings.first_launch_window(3)
	_ok("  one that fits 3x starts in a 3x window", DisplaySettings.mode == DisplaySettings.Mode.WINDOWED
		and DisplaySettings.window_scale == 3)
	DisplaySettings.path = SCRATCH
	DisplaySettings.first_launch_in_harness = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	DisplaySettings.mode = DisplaySettings.Mode.WINDOWED
	DisplaySettings.window_scale = 1
	DisplaySettings.load_and_apply()
	var top := DisplaySettings.max_window_scale()
	_ok("  no settings file: %s (largest window %dx)" % [
		"BORDERLESS" if DisplaySettings.mode == DisplaySettings.Mode.BORDERLESS else "WINDOWED %dx" % DisplaySettings.window_scale, top],
		DisplaySettings.mode == DisplaySettings.Mode.BORDERLESS if top <= 1
		else (DisplaySettings.mode == DisplaySettings.Mode.WINDOWED and DisplaySettings.window_scale == top))
	var kept := ConfigFile.new()
	_ok("  and that choice is saved", kept.load(SCRATCH) == OK
		and int(kept.get_value("display", "mode", -1)) == int(DisplaySettings.mode))
	# a player's own file, WINDOWED at 1x, read back as it is
	var own := ConfigFile.new()
	own.set_value("display", "mode", int(DisplaySettings.Mode.WINDOWED))
	own.set_value("display", "window_scale", 1)
	own.save(SCRATCH)
	DisplaySettings.load_and_apply()
	_ok("  an existing settings file is never overridden", DisplaySettings.mode == DisplaySettings.Mode.WINDOWED
		and DisplaySettings.window_scale == 1)
	DisplaySettings.first_launch_in_harness = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	DisplaySettings.path = was_path
	DisplaySettings.mode = was_mode
	DisplaySettings.window_scale = was_scale
	DisplaySettings.load_and_apply()
	await _tree.process_frame


## A RETINA MAC'S WINDOW STOPS AT 2X (`DisplaySettings.RETINA_MAX_SCALE`; Jon,
## Oct 27, ruling C2). On stand-in screens (`DisplaySettings.test_screen`,
## `test_retina`), since no machine the gate runs on is a Retina Mac and
## headless has no screen: "looks like 1440x900" (2880x1800 pixels) offers 2X
## at most and its first launch is a 2X window, where the same screen off a Mac
## still offers and opens 3X, and a 1080p screen is unchanged; a settings file
## saved before the cap at 3X opens at 2X on a Retina Mac and stays 3X off one,
## and a saved BORDERLESS is kept; Settings' WINDOW SIZE row on that Mac has no
## 3X chip, says why, and fits the drawer at 960x540 with nothing overlapping.
## A scratch settings file, never the player's.
func _retina_case() -> void:
	const SCRATCH := "user://retinatest_settings.cfg"
	const NOTE := "LARGER SIZES NEED BORDERLESS"
	var mac := Vector2i(2880, 1800)
	var was_path := DisplaySettings.path
	var was_mode := DisplaySettings.mode
	var was_scale := DisplaySettings.window_scale
	DisplaySettings.test_screen = mac
	DisplaySettings.test_retina = 1
	_ok("  a Retina Mac at 1440x900 (3X fits) offers 2X at most", DisplaySettings.fit_scale(mac) == 3
		and DisplaySettings.max_window_scale() == 2 and DisplaySettings.retina_capped())
	DisplaySettings.first_launch_window()
	_ok("  and its first launch is a 2X window", DisplaySettings.mode == DisplaySettings.Mode.WINDOWED
		and DisplaySettings.window_scale == 2)
	DisplaySettings.test_screen = Vector2i(5120, 2880)
	_ok("  a 5K Retina screen stops at 2X too", DisplaySettings.max_window_scale() == 2)
	DisplaySettings.test_screen = Vector2i(2560, 1600)
	_ok("  a Retina Mac at 1280x800 loses nothing (2X was its largest)",
		DisplaySettings.max_window_scale() == 2 and not DisplaySettings.retina_capped())
	DisplaySettings.test_retina = 0
	DisplaySettings.test_screen = mac
	DisplaySettings.first_launch_window()
	_ok("  the same 2880x1800 off a Mac still offers and opens 3X", DisplaySettings.max_window_scale() == 3
		and not DisplaySettings.retina_capped() and DisplaySettings.mode == DisplaySettings.Mode.WINDOWED
		and DisplaySettings.window_scale == 3)
	DisplaySettings.test_screen = Vector2i(1920, 1080)
	DisplaySettings.first_launch_window()
	_ok("  a 1080p screen still starts BORDERLESS", DisplaySettings.max_window_scale() == 1
		and DisplaySettings.mode == DisplaySettings.Mode.BORDERLESS)

	# SAVED BEFORE THE CAP: WINDOWED 3X and nothing newer, as 0.4.2-alpha.1 wrote it
	DisplaySettings.path = SCRATCH
	var old := ConfigFile.new()
	old.set_value("display", "mode", int(DisplaySettings.Mode.WINDOWED))
	old.set_value("display", "window_scale", 3)
	old.set_value("display", "screen", 0)
	old.save(SCRATCH)
	DisplaySettings.test_screen = mac
	DisplaySettings.test_retina = 1
	DisplaySettings.load_and_apply()
	var kept := ConfigFile.new()
	_ok("  a saved 3X window opens at 2X on a Retina Mac", DisplaySettings.mode == DisplaySettings.Mode.WINDOWED
		and DisplaySettings.window_scale == 2)
	_ok("  and 2X is what is kept", kept.load(SCRATCH) == OK
		and int(kept.get_value("display", "window_scale", 0)) == 2
		and int(kept.get_value("display", "mode", -1)) == int(DisplaySettings.Mode.WINDOWED))
	old.save(SCRATCH)
	DisplaySettings.test_retina = 0
	DisplaySettings.load_and_apply()
	_ok("  the same file stays 3X off a Mac", DisplaySettings.mode == DisplaySettings.Mode.WINDOWED
		and DisplaySettings.window_scale == 3)
	old.set_value("display", "mode", int(DisplaySettings.Mode.BORDERLESS))
	old.save(SCRATCH)
	DisplaySettings.test_retina = 1
	DisplaySettings.load_and_apply()
	_ok("  a saved BORDERLESS is kept on a Retina Mac", DisplaySettings.mode == DisplaySettings.Mode.BORDERLESS)

	# off a Mac, Settings still offers 3X and says nothing about it
	DisplaySettings.mode = DisplaySettings.Mode.WINDOWED
	DisplaySettings.window_scale = 2
	DisplaySettings.test_retina = 0
	var panel := SettingsPanel.new()
	_tree.root.add_child(panel)
	panel.build()
	await _tree.process_frame
	_ok("  off a Mac WINDOW SIZE still offers 3X, with no note", _plate(panel, "3X") != null
		and _label(panel, NOTE) == null)
	panel.queue_free()
	await _tree.process_frame

	# ON THE MAC: the title drawer, laid out in the game's own 960x540
	DisplaySettings.test_retina = 1
	_set_motion([true, false])
	_main.call("_open_settings")
	await _secs(0.3)
	var drawer: SettingsMenu = _main.get("_settings")
	if _ok("  Settings opens on a Retina Mac", drawer != null):
		var c2 := _plate(drawer, "2X")
		_ok("  WINDOW SIZE offers 1X and 2X and no 3X", _plate(drawer, "1X") != null and c2 != null
			and _plate(drawer, "3X") == null)
		_ok("  2X is lit and says why it is the largest", c2 != null and c2.lead
			and c2.tooltip_text.contains("Retina"))
		var note := _label(drawer, NOTE)
		_ok("  and the row says larger sizes need BORDERLESS", note != null)
		# THE BOX TEST: each piece of the row inside the scroll's visible rect and
		# the 960x540 picture, and none on top of another
		var scroll := first(drawer, func(n: Node) -> bool: return n is ScrollContainer) as ScrollContainer
		var key := _label(drawer, "WINDOW SIZE")
		var fps := _label(drawer, "FRAME COUNTER")
		var boxes := {
			"the WINDOW SIZE line": key.get_parent() if key != null else null,
			"1X": _plate(drawer, "1X"), "2X": c2, "the note": note,
			"the FRAME COUNTER row": fps.get_parent() if fps != null else null,
		}
		var picture := Rect2(Vector2.ZERO, Vector2(DisplaySettings.BASE))
		var view := scroll.get_global_rect() if scroll != null else Rect2()
		var bad: Array[String] = []
		var names := boxes.keys()
		for i in names.size():
			var a := boxes[names[i]] as Control
			if a == null:
				bad.append("%s missing" % names[i])
				continue
			var ra := a.get_global_rect()
			if not (picture.encloses(ra) and view.encloses(ra)):
				bad.append("%s at %s outside %s" % [names[i], ra, view])
			for j in range(i + 1, names.size()):
				var b := boxes[names[j]] as Control
				if b != null and ra.intersects(b.get_global_rect()):
					bad.append("%s overlaps %s" % [names[i], names[j]])
		_ok("  and the row fits the drawer at 960x540, nothing overlapping%s"
			% ("" if bad.is_empty() else " (" + "; ".join(bad) + ")"), bad.is_empty())
		_plate(drawer, "BACK").pressed.emit()
		await _secs(0.5)
	_set_motion([false, false])

	DisplaySettings.test_screen = Vector2i.ZERO
	DisplaySettings.test_retina = -1
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	DisplaySettings.path = was_path
	DisplaySettings.mode = was_mode
	DisplaySettings.window_scale = was_scale
	DisplaySettings.load_and_apply()
	await _tree.process_frame


## MOTION HOLDS THE PLAYER'S ROWS, EVEN IN DEV MODE. The zoom ladder's
## developer rows -- ONE CAMERA, each seam's design, 3B into the yard, the move
## timings and the station lights -- were built there under `DevMode.enabled`
## until Jon had them out, Oct 19; what he had them on is `ZoomLadder`'s
## constants. So the section, built with dev mode on, names exactly ANIMATION,
## CLICK TO SKIP JUMP, SCREEN SHAKE and FRAME CAP; and a settings file still
## holding the old `[flow]` keys loads without a word and moves nothing.
const PLAYER_MOTION := ["ANIMATION", "CLICK TO SKIP JUMP", "SCREEN SHAKE", "FRAME CAP"]
const GONE_ROWS := ["ONE CAMERA", "CHART - MAP", "MAP - LOCAL", "LOCAL - STATION",
	"3B INTO THE YARD", "MOVE TIMINGS", "STATION LIGHTS", "TIMINGS", "UI LEAVES",
	"UI ARRIVES", "TWO AT ONCE", "DOCK: THE STATION WAKES", "HANDOFF DISC SIZE (PX)",
	"HOP: THE CAMERA", "STATION OFF", "STATION ON", "LAMP GLOW"]


func _dev_motion_case() -> void:
	const SCRATCH := "user://devmotion_settings.cfg"
	var was_dev := DevMode.enabled
	var was_path := DisplaySettings.path
	DevMode.enabled = true
	_ok("  dev mode is on for the check", DevMode.enabled)
	var panel := SettingsPanel.new()
	_tree.root.add_child(panel)
	panel.build()
	await _tree.process_frame
	# the labels between MOTION's head and the next section's
	var labels: Array[String] = []
	var inside := false
	for c: Node in panel._body.get_children():
		if c is SettingsPanel.Section:
			inside = (c as SettingsPanel.Section).id == &"motion"
			continue
		if inside:
			_labels_in(c, labels)
	_ok("  MOTION names only the player's rows (%s)" % ", ".join(labels), ", ".join(labels) == ", ".join(PackedStringArray(PLAYER_MOTION)))
	var all: Array[String] = []
	_labels_in(panel, all)
	var stray := GONE_ROWS.filter(func(t: String) -> bool: return t in all)
	_ok("  and no developer row anywhere in Settings (%s)" % ", ".join(PackedStringArray(stray)), stray.is_empty())
	panel.queue_free()
	await _tree.process_frame
	# a settings file from before, every old key set away from what ships
	var old := ConfigFile.new()
	old.set_value("flow", "ladder", false)
	old.set_value("flow", "seam1", "C")
	old.set_value("flow", "seam2", "A")
	old.set_value("flow", "seam3", "D")
	old.set_value("flow", "seam3_fade", "P")
	old.set_value("flow", "calm", false)
	old.set_value("flow", "ui_out_s", 0.9)
	old.set_value("flow", "calm_cam_s", 2.5)
	old.set_value("flow", "light_on", 2.0)
	old.save(SCRATCH)
	DisplaySettings.path = SCRATCH
	DisplaySettings.load_and_apply()
	_ok("  a saved [flow] is not read: the designs are Jon's (%s %s %s, into the yard %s)" % [
		ZoomLadder.design_for(1), ZoomLadder.design_for(2), ZoomLadder.design_for(3), ZoomLadder.seam3_fade()],
		ZoomLadder.design_for(1) == "A" and ZoomLadder.design_for(2) == "C"
		and ZoomLadder.design_for(3) == "B" and ZoomLadder.seam3_fade() == "F")
	_ok("  the calm move stays on", ZoomLadder.calm_on())
	_ok("  and the timings are the baked ones (UI out %.2f, hop camera %.2f, station on %.2f)" % [
		ZoomLadder.UI_OUT_S, ZoomLadder.CALM_CAM_S, ZoomLadder.LIGHT_ON],
		is_equal_approx(ZoomLadder.UI_OUT_S, 0.22) and is_equal_approx(ZoomLadder.CALM_CAM_S, 0.8)
		and is_equal_approx(ZoomLadder.LIGHT_ON, 1.35))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	DisplaySettings.path = was_path
	DisplaySettings.load_and_apply()
	DevMode.enabled = was_dev
	await _tree.process_frame


## RUN ENDED HAS A WAY BACK TO THE TITLE (the tutorial audit, Oct 22): the only
## one was Esc and then ABANDON. Its TITLE leaves as the win's does: the title
## up, no ship.
func _run_ended_case() -> void:
	seed_run(4471)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.dead = true
	Run.death_reason = "The hull gave out."
	Router.show_game_over()
	if not _ok("  RUN ENDED is up", await _wait_for(func() -> bool:
			return Router.current is GameOverScreen)):
		return
	await _secs(0.3)
	var title := first(Router.current, func(n: Node) -> bool:
		return n is Button and (n as Button).text == "TITLE") as Button
	if not _ok("  it has a TITLE button, live", title != null and not title.disabled
			and title.is_visible_in_tree()):
		return
	title.pressed.emit()
	_ok("  TITLE goes back to the title with no ship", await _wait_for(func() -> bool:
		return Router.current is LauncherScreen) and Run.hull == null)
	Run.dead = false


## ESC ON THE HULL PICK (the tutorial audit, Oct 22): before a run launches
## there is no escape menu, whose ABANDON put a run that never started on the
## record. Esc shuts the opening deck's popup first, then goes back to the
## title, and nothing is recorded.
func _chassis_case() -> void:
	Router.new_run()
	if not _ok("  NEW RUN opens the hull pick", await _wait_for(func() -> bool:
			return Router.current is ChassisSelect)):
		return
	await _secs(0.3)
	var pick := Router.current as ChassisSelect
	var runs := RunHistory.load_all().size()
	pick._show_deck()
	await _press(KEY_ESCAPE)
	await _secs(0.3)
	_ok("  Escape shuts the opening deck's popup and stays on the hull pick",
		pick._deck_pop == null and Router.current == pick
		and _main.get("_menu") == null and _pause_menus() == 0)
	await _press(KEY_ESCAPE)
	await _secs(0.4)
	_ok("  Escape again goes back to the title, and no escape menu opens",
		Router.current is LauncherScreen and _main.get("_menu") == null and _pause_menus() == 0)
	var after := RunHistory.load_all().size()
	_ok("  and nothing goes on the record (%d runs before, %d after), no ship" % [runs, after],
		after == runs and Run.hull == null)


func _labels_in(n: Node, out: Array[String]) -> void:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_labels_in(c, out)


# ------------------------------------------------------------------- helpers

## [reduced motion, skip jump], set as the chips set them but not saved.
func _set_motion(v: Array) -> void:
	DisplaySettings.reduced_motion = bool(v[0])
	DisplaySettings.skip_jump = bool(v[1])


func _plate(root: Node, title: String) -> DrawerPlate:
	return first(root, func(n: Node) -> bool:
		return n is DrawerPlate and (n as DrawerPlate).title == title) as DrawerPlate


func _label(root: Node, text: String) -> Label:
	return first(root, func(n: Node) -> bool:
		return n is Label and (n as Label).text == text) as Label


func _pause_menus() -> int:
	var count := [0]
	_count(_tree.root, count)
	return count[0]


func _count(n: Node, count: Array) -> void:
	if n is PauseMenu and n.is_inside_tree() and not n.is_queued_for_deletion():
		count[0] += 1
	for c in n.get_children():
		_count(c, count)


func _press(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await _tree.process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	Input.parse_input_event(up)
	await _tree.process_frame


## Real time, not frames: the tweens are timed in seconds, and a headless
## frame is as short as the machine can make it.
func _secs(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await _tree.process_frame


func _wait_for(cond: Callable) -> bool:
	for i in 90:
		if cond.call():
			return true
		await _tree.process_frame
	return cond.call()


## Torn down first, as `QuitTest._finish` does.
func _finish() -> void:
	if Router.current != null:
		var last := Router.current
		Router.current = null
		last.get_parent().remove_child(last)
		last.free()
	await _tree.process_frame
	print("")
	verdict("menutest")
	_tree.quit(code())
