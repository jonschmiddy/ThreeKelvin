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
			print("graphics picked for the machine")
			await _auto_graphics_case()
			print("TUTORIAL ON / OFF")
			await _tutorial_case()
			print("SAVE MY LOGS")
			await _logs_case()
			print("the first launch's window")
			await _first_window_case()
			print("MOTION in dev mode: the player's rows only")
			await _dev_motion_case()
			print("RUN ENDED: TITLE")
			await _run_ended_case()
			print("Esc on the hull pick")
			await _chassis_case()
			print("graphics picked on the real title, end to end")
			await _title_pick_case()
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
	var was_by := DisplaySettings.graphics_by
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
	_ok("  and it is the player's now: the machine never picks again", DisplaySettings.graphics_by == DisplaySettings.GFX_PLAYER
		and str(saved.get_value("display", "graphics_by", "")) == DisplaySettings.GFX_PLAYER)
	panel.queue_free()
	await _tree.process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	DisplaySettings.path = was_path
	DisplaySettings.graphics_low = was_low
	DisplaySettings.graphics_by = was_by
	ChartRadiant.fell_back = was_fell


## GRAPHICS PICKED FOR THE MACHINE (Jon, Oct 27, ruling C1; `GpuProbe`). The
## adapter's name is a hint (Intel but not Arc is weak; Apple never), the
## measure decides (a heavy HIGH sky is LOW, a sky measured on LOW is judged by
## what HIGH would cost; a GPU that reads 0, as a Mac's does, by the title's
## median frame; no reading leaves it to the hint). A settings file from
## before `graphics_by` loads: HIGH as nobody's, LOW as the player's. Nobody's +
## a heavy measure: LOW, kept once in the file, nothing rebuilt under the
## picture (no `render_style_changed`), never decided again, and read back so.
## Settings says it beside the GRAPHICS row (a line and its tooltips), clear of
## the rows round it in the real drawer at 960x540, and HIGH pressed makes it
## the player's. The player's HIGH is never touched, by the hint or a measure.
## A forced `graphics=` / `style=` and an ordinary harness never measure or pick.
## All in a scratch settings file, the hint's adapter stood in for.
func _auto_graphics_case() -> void:
	const SCRATCH := "user://autogfx_settings.cfg"
	const INTEL := ["Intel Inc.", "Intel(R) Iris(TM) Plus Graphics 645"]
	const RTX := ["NVIDIA Corporation", "NVIDIA GeForce RTX 3070/PCIe/SSE2"]
	var was_path := DisplaySettings.path
	var was_low := DisplaySettings.graphics_low
	var was_by := DisplaySettings.graphics_by
	var was_hl := DisplaySettings._harness_low
	var was_hs := DisplaySettings._harness_style
	var was_mode := DisplaySettings.mode
	var was_scale := DisplaySettings.window_scale
	DisplaySettings.path = SCRATCH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))

	_ok("  an ordinary harness never measures for the pick", not GpuProbe.wanted())
	GpuProbe.in_harness = true

	# THE HINT
	_ok("  the hint: Intel laptop chips are weak (Mac GL, Windows, ANGLE)",
		GpuProbe.weak_by_name(INTEL[0], INTEL[1]) and GpuProbe.weak_by_name("Intel", "Intel(R) UHD Graphics 620")
		and GpuProbe.weak_by_name("Google Inc. (Intel)", "ANGLE (Intel, Intel(R) Iris(R) Xe Graphics Direct3D11 vs_5_0 ps_5_0, D3D11)"))
	_ok("  an Arc, an Apple chip, NVIDIA and AMD are not",
		not GpuProbe.weak_by_name("Intel", "Intel(R) Arc(TM) A770 Graphics")
		and not GpuProbe.weak_by_name("Apple", "Apple M1")
		and not GpuProbe.weak_by_name(RTX[0], RTX[1])
		and not GpuProbe.weak_by_name("ATI Technologies Inc.", "AMD Radeon Pro 5500M OpenGL Engine"))

	# THE VERDICT
	_ok("  the measure decides: a heavy HIGH sky is LOW, a light one HIGH, whatever the hint",
		GpuProbe.verdict(GpuProbe.LOW_MS * 3.0, false, false) and not GpuProbe.verdict(GpuProbe.LOW_MS * 0.2, false, true))
	_ok("  a sky measured on LOW is judged by what HIGH would cost",
		GpuProbe.verdict(GpuProbe.LOW_MS * GpuProbe.LOW_SHARE * 1.5, true, true)
		and not GpuProbe.verdict(GpuProbe.LOW_MS * GpuProbe.LOW_SHARE * 0.5, true, true))
	_ok("  no reading leaves it to the hint", GpuProbe.verdict(0.0, false, true) and not GpuProbe.verdict(0.0, false, false))
	_ok("  a GPU that reads 0 (a Mac): the title's frame decides, over the hint",
		GpuProbe.verdict(0.0, false, false, 33.3) and not GpuProbe.verdict(0.0, false, true, 16.7))
	_ok("  on LOW at 60 a second, HIGH is not shown to hold: LOW stays", GpuProbe.verdict(0.0, true, true, 16.7))
	_ok("  the GPU's own time, where there is one, over the frame's", not GpuProbe.verdict(GpuProbe.LOW_MS * 0.5, false, true, 40.0))
	# a real probe, stepped as the title steps it: the GPU reads 0 here as on a
	# Mac; the frames' median, one stall among them
	var vp := SubViewport.new()
	vp.size = Vector2i(8, 8)
	_tree.root.add_child(vp)
	var one: Array[SubViewport] = [vp]
	var p := GpuProbe.new(one, 20)
	var steps := 0
	var reading_mid := -1
	while not p.step(1.0, 0.5 if steps == GpuProbe.SETTLE + 3 else 1.0 / 30.0):
		steps += 1
		if steps == 5:
			reading_mid = GpuProbe.reading(vp)
	_ok("  a probe's frame is the median: %.1f ms at 30 a second, one half-second stall in it" % p.frame_ms,
		absf(p.frame_ms - 33.33) < 0.1 and p.avg_ms == 0.0 and steps == GpuProbe.SETTLE - 1 + 19)
	_ok("  its GPU timer is on while it reads and off once it is done (%d readers, then %d)" % [reading_mid, GpuProbe.reading(vp)],
		reading_mid == 1 and GpuProbe.reading(vp) == 0)
	var hid := GpuProbe.new(one, 20)
	var k := 0
	while not hid.step(1.0, 1.0 / 30.0 if k % 3 == 0 else -1.0):
		k += 1
	_ok("  a window behind others for most of it: no frame reading", hid.frame_ms == 0.0)
	# two probes on one viewport (the title's pick and RADIANT's safety share the
	# sky): the first done leaves the timer on for the other; a dropped one lets go
	var pa := GpuProbe.new(one, 20)
	var pb := GpuProbe.new(one, 40)
	while not pa.step():
		pb.step()
	var left := GpuProbe.reading(vp)
	pb.release()
	pb.release()
	_ok("  two on one viewport: the first done leaves it to the other (%d), dropped, none (%d)" % [left, GpuProbe.reading(vp)],
		left == 1 and GpuProbe.reading(vp) == 0)
	GpuProbe.force_ms = 2.0
	var fp := GpuProbe.new(one, 20)
	while not fp.step(3.0):
		pass
	GpuProbe.force_ms = -1.0
	_ok("  a harness's stand-in GPU reading is scaled as the timer's is (%.2f ms)" % fp.avg_ms, is_equal_approx(fp.avg_ms, 6.0))
	vp.queue_free()
	_ok("  a full screen of sky is the unit: the title's bigger square is scaled down",
		is_equal_approx(GpuProbe.full_sky_scale(GpuProbe.FULL_SKY), 1.0)
		and GpuProbe.full_sky_scale(GpuProbe.FULL_SKY * 2) < 0.3)

	# A SETTINGS FILE FROM BEFORE `graphics_by`, on the default HIGH
	var old := ConfigFile.new()
	old.set_value("display", "mode", int(DisplaySettings.Mode.WINDOWED))
	old.set_value("display", "window_scale", 1)
	old.set_value("display", "render_style", "simplified")
	old.set_value("display", "graphics_low", false)
	old.save(SCRATCH)
	GpuProbe.adapter_override = PackedStringArray(RTX)
	DisplaySettings.load_and_apply()
	_ok("  an old settings file loads: HIGH, set by nobody", not DisplaySettings.graphics_low
		and DisplaySettings.graphics_by == DisplaySettings.GFX_NOBODY and not DisplaySettings.low_by_machine())
	_ok("  so this machine may measure it", GpuProbe.wanted())
	# a measure that read nothing (a Mac's window behind others the whole time):
	# the name alone is never kept, and the title measures again
	_ok("  a measure that read nothing keeps nothing", not GpuProbe.conclude(0.0, false, 0.0)
		and DisplaySettings.graphics_by == DisplaySettings.GFX_NOBODY and GpuProbe.wanted())

	# NEVER CHOSEN + A WEAK MACHINE'S MEASURE
	var heard := [0]
	var on_change := func() -> void: heard[0] += 1
	Sig.render_style_changed.connect(on_change)
	# Settings open as the pick lands (the title measures in its first seconds)
	var open_panel := SettingsPanel.new()
	_tree.root.add_child(open_panel)
	open_panel.build()
	await _tree.process_frame
	var hi0 := _plate(open_panel, "HIGH")
	_ok("  Settings open before the pick: HIGH marked", hi0 != null and hi0.lead and hi0.disabled)
	_ok("  never chosen, a heavy sky: the machine picks", GpuProbe.conclude(GpuProbe.LOW_MS * 3.0, false))
	_ok("  LOW, set by the machine", DisplaySettings.graphics_low and DisplaySettings.graphics_by == DisplaySettings.GFX_MACHINE)
	await _tree.process_frame
	var hi1 := _plate(open_panel, "HIGH")
	var lo1 := _plate(open_panel, "LOW")
	_ok("  and Settings, open as it landed, redraws: LOW marked, HIGH can be pressed back",
		lo1 != null and lo1.lead and hi1 != null and not hi1.lead and not hi1.disabled
		and first(open_panel, func(n: Node) -> bool: return n is Label and n.name == &"GraphicsPicked") != null)
	open_panel.queue_free()
	var saved := ConfigFile.new()
	_ok("  kept in the settings file", saved.load(SCRATCH) == OK
		and bool(saved.get_value("display", "graphics_low", false))
		and str(saved.get_value("display", "graphics_by", "")) == DisplaySettings.GFX_MACHINE)
	_ok("  the old file's own keys kept beside it", int(saved.get_value("display", "window_scale", -1)) == 1
		and str(saved.get_value("display", "render_style", "")) == "simplified")
	_ok("  nothing rebuilt under the picture (no render_style_changed)", heard[0] == 0)
	_ok("  and the picture up keeps its pass", DisplaySettings.low_held())
	_ok("  decided once: a light measure later changes nothing",
		not GpuProbe.conclude(GpuProbe.LOW_MS * 0.1, false) and DisplaySettings.graphics_low)
	_ok("  and nothing measures again", not GpuProbe.wanted())
	DisplaySettings.load_and_apply()
	_ok("  read back next launch: LOW, the machine's, nothing held", DisplaySettings.graphics_low
		and DisplaySettings.graphics_by == DisplaySettings.GFX_MACHINE and not DisplaySettings.low_held()
		and not GpuProbe.wanted())

	# SETTINGS SAYS SO, in the real drawer at 960x540
	_main.call("_open_settings")
	await _secs(0.3)
	var drawer: SettingsMenu = _main.get("_settings")
	if _ok("  the Settings drawer opens", drawer != null):
		var panel := first(drawer, func(n: Node) -> bool: return n is SettingsPanel) as SettingsPanel
		panel._refresh()
		await _secs(0.2)
		var note := first(panel, func(n: Node) -> bool:
			return n is Label and n.name == &"GraphicsPicked") as Label
		var key := first(panel, func(n: Node) -> bool:
			return n is Label and (n as Label).text == "GRAPHICS") as Label
		var low_chip := _plate(panel, "LOW")
		var high_chip := _plate(panel, "HIGH")
		_ok("  the row reads LOW", low_chip != null and low_chip.lead and high_chip != null and not high_chip.lead)
		_ok("  a line under it says PICKED FOR THIS COMPUTER", note != null and key != null
			and note.text == "PICKED FOR THIS COMPUTER"
			and note.get_parent() == key.get_parent().get_parent()
			and note.get_index() == key.get_parent().get_index() + 1)
		_ok("  its tooltip, the row's and LOW's say why, in plain words", key != null and note != null
			and low_chip != null and key.tooltip_text.replace("\n", " ").contains("timed this computer")
			and note.tooltip_text == key.tooltip_text and key.mouse_filter != Control.MOUSE_FILTER_IGNORE
			and low_chip.tooltip_text.replace("\n", " ").contains("picked LOW for this computer"))
		if note != null and key != null:
			var row := key.get_parent() as Control
			var after := note.get_parent().get_child(note.get_index() + 1) as Control
			var nb := note.get_global_rect()
			var sb := (panel._scroll as Control).get_global_rect()
			var below := first(panel, func(n: Node) -> bool:
				return n is Label and (n as Label).text == "COLORBLINDNESS") as Label
			_ok("  box test: the line is inside the drawer's width (%s in %s)" % [nb, sb],
				nb.size.x > 0.0 and nb.position.x >= sb.position.x - 0.5 and nb.end.x <= sb.end.x + 0.5)
			_ok("  clear of the GRAPHICS row above and the next row below",
				not nb.intersects(row.get_global_rect()) and not nb.intersects(after.get_global_rect())
				and below != null and not nb.intersects((below.get_parent() as Control).get_global_rect()))
			_ok("  and every word of it shown (%d lines)" % note.get_line_count(),
				note.get_visible_line_count() == note.get_line_count() and note.size.y >= note.get_minimum_size().y - 0.5)
		heard[0] = 0
		if high_chip != null:
			high_chip.pressed.emit()
		await _secs(0.2)
		_ok("  HIGH pressed: HIGH, the player's, rebuilt at once", not DisplaySettings.graphics_low
			and DisplaySettings.graphics_by == DisplaySettings.GFX_PLAYER and heard[0] >= 1 and not DisplaySettings.low_held())
		_ok("  and the line is gone", first(panel, func(n: Node) -> bool:
			return n is Label and n.name == &"GraphicsPicked") == null)
		_plate(drawer, "BACK").pressed.emit()
		await _secs(0.5)
	Sig.render_style_changed.disconnect(on_change)

	# THE PLAYER'S HIGH IS NEVER TOUCHED, on an Intel chip and a heavy measure
	GpuProbe.adapter_override = PackedStringArray(INTEL)
	DisplaySettings.load_and_apply()
	_ok("  chose HIGH, on an Intel chip: no hint", not DisplaySettings.graphics_low
		and DisplaySettings.graphics_by == DisplaySettings.GFX_PLAYER)
	_ok("  and no measure, no pick", not GpuProbe.wanted() and not GpuProbe.conclude(GpuProbe.LOW_MS * 5.0, false)
		and not DisplaySettings.graphics_low)
	saved = ConfigFile.new()
	_ok("  the file still says HIGH, the player's", saved.load(SCRATCH) == OK
		and not bool(saved.get_value("display", "graphics_low", true))
		and str(saved.get_value("display", "graphics_by", "")) == DisplaySettings.GFX_PLAYER)

	# AN OLD FILE ON LOW: the player pressed it (HIGH was the default)
	old.set_value("display", "graphics_low", true)
	old.save(SCRATCH)
	DisplaySettings.load_and_apply()
	_ok("  an old file on LOW loads as the player's LOW", DisplaySettings.graphics_low
		and DisplaySettings.graphics_by == DisplaySettings.GFX_PLAYER and not GpuProbe.wanted())

	# THE HINT ON A LAUNCH NOBODY HAS DECIDED
	old.set_value("display", "graphics_low", false)
	old.save(SCRATCH)
	DisplaySettings.load_and_apply()
	_ok("  never chosen, an Intel chip: LOW from the first picture", DisplaySettings.graphics_low
		and DisplaySettings.graphics_by == DisplaySettings.GFX_NOBODY and DisplaySettings.low_by_machine())
	# before the measure, Settings does not say this computer was found slow: the
	# LOW is the chip's name, and the measure may put HIGH back
	var hint_panel := SettingsPanel.new()
	_tree.root.add_child(hint_panel)
	hint_panel.build()
	await _tree.process_frame
	var hint_note := first(hint_panel, func(n: Node) -> bool:
		return n is Label and n.name == &"GraphicsPicked") as Label
	var hint_low := _plate(hint_panel, "LOW")
	var hint_tip := hint_note.tooltip_text.replace("\n", " ") if hint_note != null else ""
	_ok("  Settings says LOW was started on for the chip, to be checked: \"%s\"" % hint_tip,
		DisplaySettings.low_by_hint() and hint_tip.contains("started on LOW") and hint_tip.contains("check")
		and not hint_tip.contains("timed this computer") and not hint_tip.contains("is slow")
		and hint_low != null and hint_low.tooltip_text.replace("\n", " ").contains("started on LOW"))
	hint_panel.queue_free()
	DisplaySettings.save()
	saved = ConfigFile.new()
	_ok("  in memory only: the file keeps the default until the measure", saved.load(SCRATCH) == OK
		and not bool(saved.get_value("display", "graphics_low", true))
		and str(saved.get_value("display", "graphics_by", "x")) == DisplaySettings.GFX_NOBODY)
	_ok("  measured on LOW and light: HIGH is put back, from the next picture",
		GpuProbe.conclude(GpuProbe.LOW_MS * GpuProbe.LOW_SHARE * 0.3, true) and not DisplaySettings.graphics_low
		and DisplaySettings.graphics_by == DisplaySettings.GFX_MACHINE and DisplaySettings.low_held())
	old.save(SCRATCH)
	DisplaySettings.load_and_apply()
	_ok("  measured on LOW and heavy: LOW kept, nothing to hold", GpuProbe.conclude(GpuProbe.LOW_MS, true)
		and DisplaySettings.graphics_low and DisplaySettings.graphics_by == DisplaySettings.GFX_MACHINE
		and not DisplaySettings.low_held())
	old.save(SCRATCH)
	GpuProbe.adapter_override = PackedStringArray(["Apple", "Apple M1"])
	DisplaySettings.load_and_apply()
	_ok("  an Apple chip never starts on LOW", not DisplaySettings.graphics_low and GpuProbe.wanted())

	# A LAUNCH THAT FORCED THE LOOK (`graphics=`, `style=`): what it asked for,
	# through the real parse of the command line (`DisplaySettings.harness_args`)
	GpuProbe.adapter_override = PackedStringArray(INTEL)
	DisplaySettings.harness_args = PackedStringArray(["graphics=high"])
	DisplaySettings.load_and_apply()
	_ok("  graphics=high on an Intel chip: HIGH, no hint over it", not DisplaySettings.graphics_low
		and DisplaySettings.harness_forced())
	_ok("  no measure, no pick, and the file stays nobody's", not GpuProbe.wanted()
		and not GpuProbe.conclude(GpuProbe.LOW_MS * 5.0, false) and not DisplaySettings.graphics_low
		and DisplaySettings.graphics_by == DisplaySettings.GFX_NOBODY)
	DisplaySettings._harness_low = false
	GpuProbe.adapter_override = PackedStringArray(RTX)
	DisplaySettings.harness_args = PackedStringArray(["graphics=low"])
	DisplaySettings.load_and_apply()
	_ok("  graphics=low on NVIDIA: LOW, the harness's, never called the machine's pick",
		DisplaySettings.graphics_low and not DisplaySettings.low_by_machine() and not DisplaySettings.low_by_hint()
		and not GpuProbe.wanted() and not GpuProbe.conclude(GpuProbe.LOW_MS * 0.1, false)
		and DisplaySettings.graphics_low and DisplaySettings.graphics_by == DisplaySettings.GFX_NOBODY)
	DisplaySettings._harness_low = false
	GpuProbe.adapter_override = PackedStringArray(INTEL)
	DisplaySettings.harness_args = PackedStringArray(["style=painted"])
	DisplaySettings.load_and_apply()
	_ok("  style=painted on an Intel chip: no hint, no measure, no pick", DisplaySettings.harness_style()
		and not DisplaySettings.graphics_low and not GpuProbe.wanted()
		and not GpuProbe.conclude(GpuProbe.LOW_MS * 5.0, false) and DisplaySettings.graphics_by == DisplaySettings.GFX_NOBODY)
	DisplaySettings.harness_args = PackedStringArray()
	DisplaySettings._harness_low = false
	DisplaySettings._harness_style = false

	GpuProbe.in_harness = false
	GpuProbe.adapter_override = PackedStringArray()
	DisplaySettings._harness_low = was_hl
	DisplaySettings._harness_style = was_hs
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	DisplaySettings.path = was_path
	DisplaySettings.mode = was_mode
	DisplaySettings.window_scale = was_scale
	DisplaySettings.load_and_apply()
	DisplaySettings.graphics_low = was_low
	DisplaySettings.graphics_by = was_by
	await _tree.process_frame


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


## THE PICK ON THE REAL TITLE, END TO END (the review of Oct 27). Everything in
## `_auto_graphics_case` drives `GpuProbe` and `DisplaySettings` by hand; the part
## that makes the pick had never run anywhere: the title's sky stepping its probe
## every frame (`ChartSky._gfx_step` over `sky_viewports`), `GpuProbe.conclude`,
## the picked pass compiled (`warm_place`), the title keeping the pass it has
## (`low_held` in `_push`), and the next sky drawing the pick. On an Intel Mac a
## dead measure looks like a working one (the hint has LOW up before it), so
## these titles run on chips with no hint. Headless never bakes the sky, so the
## bake's GPU products are stood in for (`ChartSky.stand_in_bake`; the CPU's
## share is real), and the dummy renderer's GPU timer reads 0, as a Mac's does:
##   A: a GPU timer (Windows) reading a heavy sky (`GpuProbe.force_ms`): LOW.
##   B: no GPU timer (a Mac), the frames slow on the wall clock: LOW.
##   C: no GPU timer, the frames as fast as they come: what they say, kept.
## RADIANT's safety on the same sky waits for the pick and never judges a held
## pass, and does judge a sky drawn as it will be. Each title over a scratch
## settings file nobody has set; each wait fails at its timeout, never hangs.
const PICK_SCRATCH := "user://titlepick_settings.cfg"
const NVIDIA := ["NVIDIA Corporation", "NVIDIA GeForce GTX 750/PCIe/SSE2"]
const RADEON := ["ATI Technologies Inc.", "AMD Radeon Pro 555 OpenGL Engine"]


## Every frame made slow on the wall clock, as a weak machine's are.
class SlowFrames extends Node:
	var ms := 40

	func _process(_d: float) -> void:
		OS.delay_msec(ms)


func _title_pick_case() -> void:
	var was_path := DisplaySettings.path
	var was_low := DisplaySettings.graphics_low
	var was_by := DisplaySettings.graphics_by
	var was_fell := ChartRadiant.fell_back
	DisplaySettings.path = PICK_SCRATCH
	GpuProbe.in_harness = true
	ChartSky.stand_in_bake = true
	var heard := [0]
	var picks := [0]
	var on_change := func() -> void: heard[0] += 1
	var on_pick := func() -> void: picks[0] += 1
	Sig.render_style_changed.connect(on_change)
	Sig.graphics_picked.connect(on_pick)
	print("  (headless, the window %s focus; the wall clock is kept only with it)" % [
		"has" if _tree.root.has_focus() else "does NOT have"])

	print("  A: a GPU timer reading a heavy sky (Windows)")
	GpuProbe.force_ms = 40.0
	var sky := await _fresh_title(NVIDIA)
	if sky != null:
		_ok("  the title's sky is built and pushed, on HIGH's pass, measuring", not sky._low_now
			and sky._m_place.shader == ChartSky.PLACE_SH and sky._gfx_tries >= 1)
		_ok("  RADIANT's safety on it waits while the pick is to come", _radiant_waits(sky))
		var at: int = picks[0]
		var landed := await _until_pick(30.0)
		if _ok("  the pick lands" + ("" if landed else _pick_diag(sky)), landed):
			var p := sky._gfx_last
			_ok("  from the title's own probe: %.1f ms of GPU for a full screen (%.1f stood in, x%.2f)" % [
				p.avg_ms if p != null else 0.0, GpuProbe.force_ms, GpuProbe.full_sky_scale(sky._vp.size)],
				p != null and p.avg_ms > GpuProbe.LOW_MS and not sky._gfx_low)
			_ok("  LOW, the machine's, kept once in the file", _picked_and_saved(true) and picks[0] == at + 1)
			_ok("  the LOW pass compiled off screen for the next picture (warm_place)", _warm_pick() == ChartSky.PLACE_LOW_SH)
			_ok("  nothing rebuilt (no render_style_changed)", heard[0] == 0)
			_ok("  the sky's GPU timers let go", _readers(sky) == 0)
			var tries := sky._gfx_tries
			await _secs(0.6)
			_ok("  the title keeps HIGH's pass under the pick, pushed for 0.6 s since", DisplaySettings.low_held()
				and not sky._low_now and sky._m_place.shader == ChartSky.PLACE_SH)
			_ok("  and measures no more (%d probes) and picks no more" % tries, sky._gfx_probe == null
				and sky._gfx_tries == tries and picks[0] == at + 1 and _readers(sky) == 0)
			_ok("  RADIANT's safety does not judge the pass the title only holds", _radiant_waits(sky))
			Router.show_launcher()
			var next := await _title_sky(30.0)
			if _ok("  a title built after it", next != null and next != sky):
				_ok("  draws the picked pass: LOW's", next._low_now and next._m_place.shader == ChartSky.PLACE_LOW_SH)
				await _secs(0.2)
				_ok("  and does not measure", next._gfx_probe == null and next._gfx_tries == 0)
				_ok("  RADIANT's safety judges a sky drawn as it will be (a heavy one goes SIMPLIFIED)",
					not _radiant_waits(next))
	GpuProbe.force_ms = -1.0

	print("  B: no GPU timer (a Mac), the frames slow")
	sky = await _fresh_title(RADEON)
	if sky != null:
		var slow := SlowFrames.new()
		_tree.root.add_child(slow)
		var at: int = picks[0]
		var landed := await _until_pick(30.0)
		var diag := "" if landed else _pick_diag(sky)
		slow.queue_free()
		if _ok("  the pick lands on the wall clock" + diag, landed):
			var p := sky._gfx_last
			_ok("  the GPU read nothing, the frames %.1f ms (over %.0f)" % [p.frame_ms if p != null else 0.0, GpuProbe.FRAME_MS],
				p != null and p.avg_ms == 0.0 and p.frame_ms > GpuProbe.FRAME_MS)
			_ok("  LOW, the machine's, kept once", _picked_and_saved(true) and picks[0] == at + 1)
			_ok("  the title keeps HIGH's pass", not sky._low_now and sky._m_place.shader == ChartSky.PLACE_SH)

	print("  C: no GPU timer, the frames as fast as they come")
	await _secs(0.2)
	sky = await _fresh_title(RADEON)
	if sky != null:
		var at: int = picks[0]
		var landed := await _until_pick(30.0)
		if _ok("  the pick lands" + ("" if landed else _pick_diag(sky)), landed):
			var p := sky._gfx_last
			var low := p != null and p.frame_ms > GpuProbe.FRAME_MS
			_ok("  the frames %.1f ms: %s, the machine's, kept once" % [p.frame_ms if p != null else 0.0, "LOW" if low else "HIGH"],
				p != null and p.frame_ms > 0.0 and _picked_and_saved(low) and picks[0] == at + 1)
			_ok("  held only if it changed", DisplaySettings.low_held() == low and not sky._low_now)

	Sig.render_style_changed.disconnect(on_change)
	Sig.graphics_picked.disconnect(on_pick)
	ChartSky.stand_in_bake = false
	ChartSky._baked.clear()
	ChartSky._early.clear()
	GpuProbe.in_harness = false
	GpuProbe.adapter_override = PackedStringArray()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PICK_SCRATCH))
	DisplaySettings.path = was_path
	DisplaySettings.load_and_apply()
	DisplaySettings.graphics_low = was_low
	DisplaySettings.graphics_by = was_by
	ChartRadiant.fell_back = was_fell
	await _tree.process_frame


## A title over a scratch settings file nobody has set GRAPHICS in, on `adapter`,
## and its sky once it is built and pushed (null, a failure, if it never is).
func _fresh_title(adapter: Array) -> ChartSky:
	var f := ConfigFile.new()
	f.set_value("display", "mode", int(DisplaySettings.Mode.WINDOWED))
	f.set_value("display", "window_scale", 1)
	f.set_value("display", "render_style", "simplified")
	f.set_value("display", "graphics_low", false)
	f.save(PICK_SCRATCH)
	GpuProbe.adapter_override = PackedStringArray(adapter)
	DisplaySettings.load_and_apply()
	if not _ok("  nobody has set GRAPHICS (%s): HIGH, no hint, to be measured" % adapter[1],
			DisplaySettings.graphics_by == DisplaySettings.GFX_NOBODY and not DisplaySettings.graphics_low
			and GpuProbe.wanted()):
		return null
	Router.show_launcher()
	var sky := await _title_sky(60.0)
	_ok("  the title's sky is built headless (its bake stood in for)", sky != null)
	return sky


## The current title's sky, once it has its viewports and has been pushed.
func _title_sky(timeout: float) -> ChartSky:
	var l := Router.current as LauncherScreen
	var until := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < until:
		if l != null and is_instance_valid(l) and l._sky != null and l._sky._sky != null:
			var s: ChartSky = l._sky._sky
			if s._m_place != null and s._lut_on and not s.sky_viewports().is_empty():
				# (the probe starts the frame after the viewports are built)
				await _tree.process_frame
				await _tree.process_frame
				return s
		await _tree.process_frame
	return null


## Frames until the machine's pick is kept, or false at `timeout` seconds.
func _until_pick(timeout: float) -> bool:
	var until := Time.get_ticks_msec() + int(timeout * 1000.0)
	while DisplaySettings.graphics_by == DisplaySettings.GFX_NOBODY:
		if Time.get_ticks_msec() > until:
			return false
		await _tree.process_frame
	return true


## Why a pick never landed: how far the title's probe got.
func _pick_diag(sky: ChartSky) -> String:
	var p := sky._gfx_probe
	return " (NOT in time: %d probes started; this one %d frames, %d counted, %d frame lengths kept; focus %s, cap %d)" % [
		sky._gfx_tries, p.frames if p != null else -1, p.n if p != null else -1, p.gaps.size() if p != null else -1,
		sky.get_window().has_focus(), Engine.max_fps]


## The machine's pick is `low`, in memory and in the scratch file.
func _picked_and_saved(low: bool) -> bool:
	var f := ConfigFile.new()
	return DisplaySettings.graphics_low == low and DisplaySettings.graphics_by == DisplaySettings.GFX_MACHINE \
		and f.load(PICK_SCRATCH) == OK and bool(f.get_value("display", "graphics_low", not low)) == low \
		and str(f.get_value("display", "graphics_by", "")) == DisplaySettings.GFX_MACHINE


## The shader `ChartSky.warm_place` is compiling off screen, or null.
func _warm_pick() -> Shader:
	for c in _tree.root.get_children():
		if String(c.name).begins_with("ChartSkyWarmPick") and c.get_child_count() > 0:
			var r := c.get_child(0) as ColorRect
			if r != null and r.material is ShaderMaterial:
				return (r.material as ShaderMaterial).shader
	return null


## How many probes are reading the sky's viewports.
func _readers(sky: ChartSky) -> int:
	var n := 0
	for v in sky.sky_viewports():
		n += GpuProbe.reading(v)
	return n


## RADIANT's safety on `sky` as if the style were RADIANT, its probe reading a
## heavy sky past its end: true if it waited (RADIANT kept). All put back after
## (a fall-back saves SIMPLIFIED to the scratch file, which already says it).
func _radiant_waits(sky: ChartSky) -> bool:
	var style := DisplaySettings.render_style
	var fell := ChartRadiant.fell_back
	var force := GpuProbe.force_ms
	var was := sky._radiant_probe
	DisplaySettings.render_style = &"radiant"
	GpuProbe.force_ms = 100.0
	var rp := GpuProbe.new(sky.sky_viewports(), 5)
	sky._radiant_probe = rp
	for i in GpuProbe.SETTLE + 10:
		sky._radiant_safety()
	var waited := not ChartRadiant.fell_back and DisplaySettings.render_style == &"radiant"
	rp.release()
	sky._radiant_probe = was
	DisplaySettings.render_style = style
	ChartRadiant.fell_back = fell
	GpuProbe.force_ms = force
	return waited


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
