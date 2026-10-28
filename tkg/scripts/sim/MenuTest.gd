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
			print("FRAME CAP and VSYNC")
			await _pacing_case()
			print("FRAME CAP and VSYNC fit the escape drawer")
			await _pacing_fit_case()
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


## FRAME CAP AND VSYNC (Jon, Oct 27, perf C3: "yes"). FRAME CAP offers NONE,
## 30, 60 and 120; VSYNC is ON or OFF, and OFF only with a cap: OFF with the
## cap at NONE sets it to 60, and NONE turns VSYNC back on. Every value reaches
## `Engine.max_fps` and the window's V-Sync (`applied_vsync`, which is what was
## handed to `window_set_vsync_mode`, and the window's own reading when there
## is a window to ask). A file from before VSYNC loads ON with its cap and
## leaves the window's V-Sync alone; one that says OFF with no cap loads ON.
## Pressed through the real chips, in a scratch settings file, never the
## player's.
func _pacing_case() -> void:
	const SCRATCH := "user://pacingtest_settings.cfg"
	var was_path := DisplaySettings.path
	DisplaySettings.path = SCRATCH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	var windowed := DisplayServer.get_name() != "headless"
	_ok("  FRAME CAP's steps are NONE, 30, 60 and 120 (%s)" % [DisplaySettings.FRAME_CAPS],
		str(DisplaySettings.FRAME_CAPS) == "[0, 30, 60, 120]")
	# a settings file from before VSYNC (and before 30): no vsync key
	var old := ConfigFile.new()
	old.set_value("display", "mode", int(DisplaySettings.mode))
	old.set_value("display", "window_scale", DisplaySettings.window_scale)
	old.save(SCRATCH)
	DisplaySettings.load_and_apply()
	_ok("  an old file with neither key: no cap, VSYNC ON (max_fps %d)" % Engine.max_fps,
		DisplaySettings.frame_cap == 0 and Engine.max_fps == 0 and DisplaySettings.vsync)
	_ok("  and the window's V-Sync is left as Godot opened it (applied %d)" % DisplaySettings.applied_vsync,
		DisplaySettings.applied_vsync == -1)
	old.set_value("display", "frame_cap", 60)
	old.save(SCRATCH)
	DisplaySettings.load_and_apply()
	_ok("  an old file capped at 60: 60 and VSYNC ON", DisplaySettings.frame_cap == 60
		and Engine.max_fps == 60 and DisplaySettings.vsync and DisplaySettings.applied_vsync == -1)
	DisplaySettings.set_frame_cap(0)

	var panel := SettingsPanel.new()
	_tree.root.add_child(panel)
	panel.build()
	await _tree.process_frame
	var cap := _row_plates(panel, "FRAME CAP")
	var vs := _row_plates(panel, "VSYNC")
	_ok("  FRAME CAP's chips: %s, NONE picked" % _titles(cap),
		_titles(cap) == "NONE 30 60 120" and _picked(cap) == "NONE")
	_ok("  VSYNC's chips: %s, ON picked" % _titles(vs), _titles(vs) == "ON OFF" and _picked(vs) == "ON")
	var tipped := cap.all(func(p: DrawerPlate) -> bool: return p.tooltip_text != "") \
		and vs.all(func(p: DrawerPlate) -> bool: return p.tooltip_text != "")
	_ok("  every chip in both rows says what it does", tipped and not cap.is_empty() and not vs.is_empty())
	if vs.size() == 2 and cap.size() == 4:
		var off_tip := (vs[1] as DrawerPlate).tooltip_text.replace("\n", " ")
		var none_tip := (cap[0] as DrawerPlate).tooltip_text.replace("\n", " ")
		_ok("  VSYNC OFF's says it needs a cap, what NONE does to it, and has no dash",
			off_tip.contains("FRAME CAP at NONE") and off_tip.contains("60")
			and off_tip.contains("back to NONE turns VSYNC on") and not off_tip.contains(" -"))
		_ok("  FRAME CAP NONE's says it turns VSYNC back on", none_tip.contains("turns VSYNC back on"))

	# 30, with VSYNC ON
	await _press_chip(panel, "FRAME CAP", "30")
	_ok("  pressing 30 caps at 30 (max_fps %d), VSYNC stays ON" % Engine.max_fps,
		DisplaySettings.frame_cap == 30 and Engine.max_fps == 30 and DisplaySettings.vsync)
	_ok("  and keeps it", _saved(SCRATCH, "frame_cap", -1) == 30)
	# OFF, with a cap already set: the cap stays
	await _press_chip(panel, "VSYNC", "OFF")
	_ok("  VSYNC OFF at 30: OFF, the cap stays 30", not DisplaySettings.vsync
		and DisplaySettings.frame_cap == 30 and Engine.max_fps == 30)
	_ok("  and the window is told: V-Sync disabled (applied %d)" % DisplaySettings.applied_vsync,
		DisplaySettings.applied_vsync == DisplayServer.VSYNC_DISABLED)
	if windowed:
		_ok("  the window reads it back (%d)" % DisplayServer.window_get_vsync_mode(),
			DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED)
	_ok("  and keeps it", _saved(SCRATCH, "vsync", true) == false)
	# NONE while OFF: VSYNC comes back on
	await _press_chip(panel, "FRAME CAP", "NONE")
	_ok("  FRAME CAP NONE while VSYNC is OFF: no cap, VSYNC back ON",
		DisplaySettings.frame_cap == 0 and Engine.max_fps == 0 and DisplaySettings.vsync)
	_ok("  and the window is told: V-Sync enabled (applied %d)" % DisplaySettings.applied_vsync,
		DisplaySettings.applied_vsync == DisplayServer.VSYNC_ENABLED)
	if windowed:
		_ok("  the window reads it back (%d)" % DisplayServer.window_get_vsync_mode(),
			DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED)
	_ok("  and the row shows ON", _picked(_row_plates(panel, "VSYNC")) == "ON")
	_ok("  both kept", _saved(SCRATCH, "frame_cap", -1) == 0 and _saved(SCRATCH, "vsync", false) == true)
	# OFF with no cap: the cap goes to 60
	await _press_chip(panel, "VSYNC", "OFF")
	_ok("  VSYNC OFF with no cap: OFF, and capped at 60 (max_fps %d)" % Engine.max_fps,
		not DisplaySettings.vsync and DisplaySettings.frame_cap == 60 and Engine.max_fps == 60)
	_ok("  the window is told (applied %d)" % DisplaySettings.applied_vsync,
		DisplaySettings.applied_vsync == DisplayServer.VSYNC_DISABLED)
	_ok("  and FRAME CAP shows 60, VSYNC OFF",
		_picked(_row_plates(panel, "FRAME CAP")) == "60" and _picked(_row_plates(panel, "VSYNC")) == "OFF")
	_ok("  both kept", _saved(SCRATCH, "frame_cap", -1) == 60 and _saved(SCRATCH, "vsync", true) == false)
	# read back, from a cold start of the values
	DisplaySettings.vsync = true
	DisplaySettings.frame_cap = 0
	Engine.max_fps = 0
	DisplaySettings.load_and_apply()
	_ok("  read back: OFF at 60, max_fps %d, the window told (applied %d)" % [Engine.max_fps, DisplaySettings.applied_vsync],
		not DisplaySettings.vsync and DisplaySettings.frame_cap == 60 and Engine.max_fps == 60
		and DisplaySettings.applied_vsync == DisplayServer.VSYNC_DISABLED)
	# a file that says OFF with no cap is never unlimited
	var bad := ConfigFile.new()
	bad.load(SCRATCH)
	bad.set_value("display", "frame_cap", 0)
	bad.set_value("display", "vsync", false)
	bad.save(SCRATCH)
	DisplaySettings.load_and_apply()
	_ok("  a file saying OFF with no cap loads ON, and the window gets V-Sync back (applied %d)" % DisplaySettings.applied_vsync,
		DisplaySettings.vsync and DisplaySettings.frame_cap == 0 and Engine.max_fps == 0
		and DisplaySettings.applied_vsync == DisplayServer.VSYNC_ENABLED)
	# OFF at 120, then ON: the cap is the player's and stays
	panel._refresh()
	await _press_chip(panel, "FRAME CAP", "120")
	await _press_chip(panel, "VSYNC", "OFF")
	_ok("  VSYNC OFF at 120 keeps 120", not DisplaySettings.vsync and DisplaySettings.frame_cap == 120 and Engine.max_fps == 120)
	await _press_chip(panel, "VSYNC", "ON")
	_ok("  VSYNC ON again keeps 120 too", DisplaySettings.vsync and DisplaySettings.frame_cap == 120
		and Engine.max_fps == 120 and DisplaySettings.applied_vsync == DisplayServer.VSYNC_ENABLED)
	panel.queue_free()
	await _tree.process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	DisplaySettings.path = was_path
	DisplaySettings.load_and_apply()
	_ok("  back on the harness's own settings: no cap, VSYNC ON", DisplaySettings.frame_cap == 0
		and Engine.max_fps == 0 and DisplaySettings.vsync)
	await _tree.process_frame


## THE TWO ROWS FIT, in the escape drawer as it opens over the ship at
## 960x540: the drawer keeps its width, every chip and label sits inside the
## settings column and on screen, nothing in either row touches anything else
## (each other, the rows above and below, the next section), and each chip's
## word fits its chip.
func _pacing_fit_case() -> void:
	await _press(KEY_ESCAPE)
	await _secs(0.4)
	var menu: PauseMenu = _main.get("_menu")
	if not _ok("  Escape opens the menu", menu != null):
		return
	_plate(menu, "SETTINGS").pressed.emit()
	await _secs(0.4)
	var panel := menu._settings as SettingsPanel
	if _ok("  and Settings", panel != null):
		panel.show_section(&"motion")
		await _secs(0.1)
		var screen := Rect2(Vector2.ZERO, Vector2(960, 540))
		# (the menu sits in the game's own view, GameShell's 960x540, not
		# the headless window's 64 px square)
		print("  the menu's view: %s" % menu.get_viewport().get_visible_rect())
		var drawer := menu._drawer.get_global_rect()
		var least := menu._drawer.get_combined_minimum_size().x
		_ok("  the drawer is still %d px wide (%s; its contents need %.0f)" % [int(PauseMenu.DRAWER_W), drawer, least],
			is_equal_approx(drawer.size.x, PauseMenu.DRAWER_W) and least <= PauseMenu.DRAWER_W)
		var column := panel._body.get_global_rect()
		var shown := panel._scroll.get_global_rect()
		_ok("  the settings column stays inside the scroll (%s in %s)" % [column, shown],
			column.end.x <= shown.end.x + 0.5 and column.position.x >= shown.position.x - 0.5)
		# every box in MOTION and the head after it, with its name
		var boxes: Array = []
		var inside := false
		for c: Node in panel._body.get_children():
			if c is SettingsPanel.Section:
				if inside:
					boxes.append(["section " + (c as SettingsPanel.Section).text, (c as Control).get_global_rect()])
					break
				inside = (c as SettingsPanel.Section).id == &"motion"
				continue
			if inside:
				for k in (c as Node).find_children("*", "Control", true, false):
					if k is Label:
						boxes.append(["label " + (k as Label).text, (k as Control).get_global_rect()])
					elif k is DrawerPlate:
						boxes.append(["chip " + (k as DrawerPlate).title + " of " + _row_name(k), (k as Control).get_global_rect()])
		var ours := boxes.filter(func(b: Array) -> bool:
			return String(b[0]).ends_with("FRAME CAP") or String(b[0]).ends_with("VSYNC"))
		_ok("  found FRAME CAP's 5 boxes and VSYNC's 3 (%d)" % ours.size(), ours.size() == 8)
		var hits: Array = []
		var outside: Array = []
		for o: Array in ours:
			var r: Rect2 = o[1]
			if not (r.size.x > 0.0 and r.size.y > 0.0 and column.grow(0.5).encloses(r)
					and shown.grow(0.5).encloses(r) and screen.encloses(r)):
				outside.append("%s %s" % [o[0], r])
			for b: Array in boxes:
				if b[0] != o[0] and r.intersects(b[1] as Rect2):
					hits.append("%s / %s" % [o[0], b[0]])
		_ok("  each inside the column, the scroll's view and the 960x540 screen%s"
			% ("" if outside.is_empty() else ": " + ", ".join(outside)), outside.is_empty() and not ours.is_empty())
		_ok("  and touching nothing (%d boxes checked)%s" % [boxes.size(),
			"" if hits.is_empty() else ": " + ", ".join(hits.slice(0, 6))], hits.is_empty())
		var tight: Array = []
		for name: String in ["FRAME CAP", "VSYNC"]:
			for p: DrawerPlate in _row_plates(panel, name):
				var font := p.get_theme_font("font", "Label")
				var tw := font.get_string_size(p.title, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
				if tw + 4.0 > p.size.x:
					tight.append("%s %.0f in %.0f" % [p.title, tw, p.size.x])
		_ok("  each chip's word fits its chip%s" % ("" if tight.is_empty() else ": " + ", ".join(tight)), tight.is_empty())
	await _press(KEY_ESCAPE)
	await _secs(0.3)
	await _press(KEY_ESCAPE)
	await _secs(0.5)
	_ok("  and the menu shuts again", _main.get("_menu") == null and _pause_menus() == 0)


## The chips of the row named `label` in `panel`, in order.
func _row_plates(panel: Node, label: String) -> Array:
	var lab := first(panel, func(n: Node) -> bool:
		return n is Label and (n as Label).text == label)
	if lab == null:
		return []
	var out: Array = []
	for n in lab.get_parent().find_children("*", "DrawerPlate", true, false):
		out.append(n)
	return out


## The name of the `_row_chips` row a chip sits in (its label's text).
func _row_name(chip: Node) -> String:
	var row := chip.get_parent().get_parent() if chip.get_parent() != null else null
	if row != null and row.get_child_count() > 0 and row.get_child(0) is Label:
		return (row.get_child(0) as Label).text
	return "?"


func _titles(plates: Array) -> String:
	return " ".join(PackedStringArray(plates.map(func(p: DrawerPlate) -> String: return p.title)))


## The lit chip's word, or "" if none is lit.
func _picked(plates: Array) -> String:
	for p: DrawerPlate in plates:
		if p.lead:
			return p.title
	return ""


## Press the chip `title` in the row `label`, as a click does, and let the
## panel rebuild.
func _press_chip(panel: Node, label: String, title: String) -> void:
	for p: DrawerPlate in _row_plates(panel, label):
		if p.title == title:
			p.pressed.emit()
			break
	await _tree.process_frame


func _saved(file: String, key: String, fallback: Variant) -> Variant:
	var cfg := ConfigFile.new()
	if cfg.load(file) != OK:
		return fallback
	return cfg.get_value("display", key, fallback)


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
			# (a box with no size is inside everything and overlaps nothing)
			if ra.size.x < 1.0 or ra.size.y < 1.0:
				bad.append("%s has no size" % names[i])
			elif not (picture.encloses(ra) and view.encloses(ra)):
				bad.append("%s at %s outside %s" % [names[i], ra, view])
			for j in range(i + 1, names.size()):
				var b := boxes[names[j]] as Control
				if b != null and ra.intersects(b.get_global_rect()):
					bad.append("%s overlaps %s" % [names[i], names[j]])
		_ok("  and the row fits the drawer at 960x540, nothing overlapping (the note %s in %s)%s"
			% [note.get_global_rect() if note != null else Rect2(), view,
			"" if bad.is_empty() else ": " + "; ".join(bad)], bad.is_empty())
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
## CLICK TO SKIP JUMP, SCREEN SHAKE, FRAME CAP and VSYNC (Oct 27); and a settings file still
## holding the old `[flow]` keys loads without a word and moves nothing.
const PLAYER_MOTION := ["ANIMATION", "CLICK TO SKIP JUMP", "SCREEN SHAKE", "FRAME CAP", "VSYNC"]
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
