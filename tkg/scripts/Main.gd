extends Control
## Entry point. Builds the theme, the persistent HUD, and hands the content
## area to Router. Everything else is created in code by the screens.

func _ready() -> void:
	# Harnesses get the framed 1920x1080 window; players keep the small borderless one.
	if TestRun.active():
		DisplaySettings.leave_launch_window()
	_wear_cursor()
	# Read first: HeadlessSim and the tests start runs of their own, and the seed replays a bug.
	var argv0 := OS.get_cmdline_user_args()
	for i in argv0.size():
		if argv0[i] == "seed" and i + 1 < argv0.size():
			Rng.forced = int(argv0[i + 1])
			print("Seeded run: %d" % Rng.forced)

	_dev = DevFlags.new(self)
	# Harness flags that run instead of the game: nothing below is built for them.
	# Why: docs/why/DevFlags.md#tables
	if _dev.dispatch(DevFlags.EARLY):
		return

	DisplaySettings.load_and_apply()
	DevMode.load_settings()
	# Read before the theme is built, the only moment it can be read.
	for a_btn in OS.get_cmdline_user_args():
		if (a_btn as String).begins_with("btn="):
			UITheme.button_style = clampi(int((a_btn as String).substr(4)), 0, 5) as UITheme.ButtonStyle
	theme = UITheme.build()

	var margin := Widgets.pad(null, 8, 7)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

	# Added to the window, not `root`, so it cannot take a pixel from the HUD row.
	# Why: docs/why/Main.md#frame-counter
	add_child(FpsMeter.new())
	# THE HULL FAILING (`LowHull`): a faint red at the edges and the odd glitch
	# in the words, on a layer of its own over the game and under the menu.
	add_child(LowHull.new())
	# A LINE FROM THE PARTY that every screen shows until clicked: the galaxies
	# of two machines in one party do not match (`NetSession._galaxy_differs_here`).
	add_child(PartyNotice.new())

	Router.register(content, hud)
	# Kicked on the landing, not the resolution, or the shake ended ten frames before the shot.
	# Why: docs/why/Main.md#hit-kick
	Sig.hit_landed.connect(func(amount: int, to_player: bool, _who: int, _ab: int) -> void:
		if to_player and amount > 0:
			_kick(amount))

	if _dev.dispatch(DevFlags.REGISTERED):
		return

	# Dev flags skip the launcher; `ship` and `salvage` need a run or the screen crashes.
	# Why: docs/why/Main.md#boot-destination
	var argv := OS.get_cmdline_user_args()
	var skip_launcher := "nolauncher" in argv or "cards" in argv or "fight" in argv \
		or "charttest" in argv or "ship" in argv or "station" in argv \
		or "salvage" in argv or "party" in argv \
		or "quest" in argv or "parts" in argv or "gameover" in argv
	# Own branch, not in skip_launcher: a lobby must not start a run before the seed is agreed.
	if "lobby" in argv:
		Router.show_lobby()
	elif "resume" in argv and SaveGame.has_save():
		Router.continue_run()
	elif skip_launcher:
		Router.new_run()
	else:
		Router.show_launcher()

	if _dev.dispatch(DevFlags.BOOTED):
		return
	_dev.dispatch_first(DevFlags.SHORTCUTS)

	# `-- shot` is generic: it photographs whatever the flags put up, so no case per screen.
	# Why: docs/why/Main.md#shot-flags
	if "menu" in OS.get_cmdline_user_args():
		toggle_menu()
	# Display options for one run, for shots; they are not saved.
	for a0 in OS.get_cmdline_user_args():
		if (a0 as String).begins_with("look="):
			var want := (a0 as String).substr(5).to_upper()
			var names := ["FLAT", "LINES", "CRT", "CRT+", "ARCADE"]
			DisplaySettings.screen_look = maxi(names.find(want), 0) as DisplaySettings.Look
		if (a0 as String).begins_with("phase="):
			TransferView.Arrow.freeze = float((a0 as String).substr(6))
		# `-- off=0.5` freezes the set halfway through switching off, for
		# photographing a moment nobody can pause in play.
		if (a0 as String).begins_with("off="):
			if GameShell.instance != null:
				GameShell.instance.hold_off(float((a0 as String).substr(4)))
		# `-- ptr=960,540` pretends the pointer is there, so a shot tool can
		# photograph the nudge at a chosen place on the glass.
		if (a0 as String).begins_with("ptr="):
			var xy := (a0 as String).substr(4).split(",")
			if xy.size() == 2 and GameShell.instance != null:
				GameShell.instance._pointer = Vector2(float(xy[0]), float(xy[1]))
		if (a0 as String).begins_with("vig="):
			GameShell._vig_override = clampf(float((a0 as String).substr(4)), 0.0, 1.0)
		if (a0 as String).begins_with("edge="):
			GameShell._edge_style = clampi(int((a0 as String).substr(5)), 0, 7)
		if (a0 as String).begins_with("cvd="):
			DisplaySettings.colour_help = clampi(int((a0 as String).substr(4)), 0, 3)
	GameShell.refresh()

	# Checks the keyboard still reaches the game now that it lives in a SubViewport.
	if "keytest" in OS.get_cmdline_user_args():
		_key_test.call_deferred()

	# `-- gameover`: the run-ended panel, for looking at it without dying.
	if "gameover" in OS.get_cmdline_user_args():
		Run.death_reason = "Hull integrity lost. The cold gets in fast."
		Router.show_game_over.call_deferred()

	# A wreck with one COMMON module, opened, to hear the rarity ladder's quietest rung.
	if "salvage" in OS.get_cmdline_user_args():
		_open_test_salvage.call_deferred()

	# `-- settings`, the same for the Settings drawer; `-- confirm` for the
	# escape menu's "abandon this run?" step.
	if "settings" in OS.get_cmdline_user_args():
		_open_settings()
	# Opens Settings at CONTROLS; `bindshot` poses a row in a state worth photographing.
	for a_k in OS.get_cmdline_user_args():
		if a_k == "settings=controls" or (a_k as String).begins_with("bindshot="):
			_open_settings()
			_show_keys.call_deferred()
			break
		# `-- settings=motion`: scrolled to MOTION, for a still of it; `settings=look`
		# to THE LOOK (GRAPHICS, and with `gfxprobe` the machine's pick beside it)
		if a_k == "settings=motion" or a_k == "settings=look":
			_open_settings()
			_show_section.call_deferred(StringName((a_k as String).substr(9)))
			break
	if "confirm" in OS.get_cmdline_user_args() and _menu != null:
		_menu.confirm(true)
	if _wants_shot():
		_shoot()

## `-- shot` or `-- shot=path`. Both spellings, because a flag that silently
## does nothing when you name a file is worse than no flag.
func _wants_shot() -> bool:
	for a in OS.get_cmdline_user_args():
		if a == "shot" or a.begins_with("shot="):
			return true
	return false

## Wait several frames: containers size children a frame after adding, so frame zero lies.
## Why: docs/why/Main.md#shot-timing
func _shoot() -> void:
	# Resize the window to the base viewport first, or the PNG silently crops the interface.
	# Why: docs/why/Main.md#shot-timing
	var base := Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 540)))
	get_window().size = base
	for i in 8:
		await get_tree().process_frame
	# Shoot the measured pick, not the hint: the title sky needs about a hundred frames.
	if GpuProbe.asked() != "":
		var until := Time.get_ticks_msec() + 30000
		while DisplaySettings.graphics_by == DisplaySettings.GFX_NOBODY and Time.get_ticks_msec() < until:
			await get_tree().process_frame
		for i in 8:
			await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var out := "user://shot.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shot="):
			out = a.split("=")[1]
	img.save_png(out)
	# Print both texture and layout sizes: a PNG can be narrower than the interface in it.
	# Why: docs/why/Main.md#shot-timing
	print("[shot] %s  texture %dx%d  layout %dx%d" % [
		ProjectSettings.globalize_path(out), img.get_width(), img.get_height(),
		int(size.x), int(size.y)])
	get_tree().quit()

## Owns the harness flag tables and holds the tests that outlive `_ready`.
var _dev: DevFlags

var _menu: PauseMenu = null

## Menu has its own layer so its blur sees the whole game, including `top_level` controls.
## A CanvasLayer is not a Control, so hand it `theme` by hand or it uses the default font.
## Why: docs/why/Main.md#overlay-layer
var _overlay: CanvasLayer = null

func _overlay_layer() -> CanvasLayer:
	if _overlay == null:
		_overlay = CanvasLayer.new()
		_overlay.layer = 10
		add_child(_overlay)
	return _overlay
var _settings: SettingsMenu = null

## Tab is caught in `_input`: the GUI eats it for focus walking, which this game never uses.
## The cursor is four swapped frames: a painted Control cursor would lag the mouse.
## Why: docs/why/Main.md#input-and-cursor
const CURSOR_FRAMES := 4
## The pixel you are pointing with: the middle, for a shape that closes around
## it rather than an arrow that points from a corner.
const CURSOR_HOT := Vector2(16, 16)
## Frames per second of travel. Nine hundredths of a second end to end, which is
## fast enough to feel like a response and slow enough to see happen.
const CURSOR_SPEED := 34.0
## Every shape the reticle stands in for: the two of hovering, and the four a
## drag can ask for.
const CURSOR_SHAPES := [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND,
	Input.CURSOR_FORBIDDEN, Input.CURSOR_CAN_DROP, Input.CURSOR_DRAG, Input.CURSOR_MOVE]

var _cursor_tex: Array[ImageTexture] = []
## Where the animation currently is, 0 open to 3 closed. Fractional between.
var _cursor_at: float = 0.0
## Which frame the operating system is actually holding, to avoid handing it the
## same image sixty times a second.
var _cursor_shown: int = -1


func _wear_cursor() -> void:
	_cursor_tex.clear()
	for i in CURSOR_FRAMES:
		# Load via the imported texture: an export has no loose PNG, so friends got the arrow.
		# Why: docs/why/Main.md#cursor
		var tex := load("res://art/cursors/reticle_%d_2x.png" % i) as Texture2D
		if tex == null:
			return
		_cursor_tex.append(ImageTexture.create_from_image(tex.get_image()))
	_show_cursor(0)


func _show_cursor(f: int) -> void:
	if f == _cursor_shown or f < 0 or f >= _cursor_tex.size():
		return
	_cursor_shown = f
	# Both shapes and every drag shape wear the same frame, so Godot's swaps stay invisible.
	# Why: docs/why/Main.md#cursor
	for shape in CURSOR_SHAPES:
		Input.set_custom_mouse_cursor(_cursor_tex[f],
			shape as Input.CursorShape, CURSOR_HOT)


## Reads `mouse_default_cursor_shape`, the fact `Widgets._btn` declares and Godot would read.
## Why: docs/why/Main.md#cursor
func _cursor_wants_shut() -> bool:
	# A held button is a grip: one rule covers drags and holds, and keeps a click shut.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return true
	var h := get_viewport().gui_get_hovered_control()
	return h != null and h.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND


func _process(delta: float) -> void:
	_shake_step(delta)
	if _cursor_tex.is_empty():
		return
	var want := float(CURSOR_FRAMES - 1) if _cursor_wants_shut() else 0.0
	_cursor_at = move_toward(_cursor_at, want, delta * CURSOR_SPEED)
	_show_cursor(int(round(_cursor_at)))


## The viewport moves, in whole pixels only, so a half-pixel never resamples every sprite.
## Why: docs/why/Main.md#screen-shake
const SHAKE_S := 0.22
const SHAKE_HZ := 34.0
const SHAKE_MAX := 4.0
var _shake: float = 0.0            ## seconds left
var _shake_px: float = 0.0         ## amplitude this kick started at

func _key_test() -> void:
	for _i in 20:
		await get_tree().process_frame
	var was := Router.current
	_press(KEY_ESCAPE)
	await get_tree().process_frame
	print("[keytest] ESC opened the menu: %s" % [_menu != null])
	_press(KEY_ESCAPE)
	await get_tree().process_frame
	print("[keytest] ESC closed it again: %s" % [_menu == null])
	_press(KEY_TAB)
	await get_tree().process_frame
	await get_tree().process_frame
	print("[keytest] TAB changed the page: %s (%s -> %s)" % [
		Router.current != was, was, Router.current])
	get_tree().quit()

func _press(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventKey.new()
	up.keycode = code
	up.pressed = false
	Input.parse_input_event(up)

## Hit for `amount`: a nick is one pixel, a big hit is four.
func _kick(amount: int) -> void:
	if not DisplaySettings.screen_shake or not Router.animating():
		return
	_shake_px = clampf(1.0 + float(amount) / 6.0, 1.0, SHAKE_MAX)
	_shake = SHAKE_S

func _shake_step(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = maxf(0.0, _shake - delta)
	var amp := _shake_px * (_shake / SHAKE_S)
	var t := (SHAKE_S - _shake) * SHAKE_HZ * TAU
	var at := Vector2(roundf(sin(t) * amp), roundf(cos(t * 0.7) * amp * 0.6))
	if _shake <= 0.0:
		at = Vector2.ZERO
	var tr := get_viewport().canvas_transform
	tr.origin = at
	get_viewport().canvas_transform = tr


func _input(event: InputEvent) -> void:
	# Snap shut, ease open: a press is an impact. The click is watched but not handled.
	# Why: docs/why/Main.md#cursor
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_cursor_at = float(CURSOR_FRAMES - 1)
		_show_cursor(CURSOR_FRAMES - 1)
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	# A bare Tab is still eaten for focus; a letter binding yields to a focused text field.
	if not k.is_action_pressed(&"next_screen"):
		if k.keycode == KEY_TAB and Keys.clashes(&"next_screen", KEY_TAB).is_empty():
			get_viewport().set_input_as_handled()
		return
	if k.keycode != KEY_TAB and get_viewport().gui_get_focus_owner() is LineEdit:
		return
	get_viewport().set_input_as_handled()
	# Only inside a run: Tab on hull pick had no ship, and the menu freezes the page behind.
	if Run.hull == null or Router.is_front_door(Router.current) or _menu != null:
		return
	# Not off the move: Tab over the yard swapped the station out and lost the pad (Jon, Oct 23).
	# Why: docs/why/Main.md#tab-round
	if Router.move_open():
		return
	# Not off the end of a run: Tab would reopen LOCAL in a run that is already over.
	if Router.final_loot or Router.current is GameOverScreen:
		return
	# The round is LOCAL, SECTOR, STARCHART; docked, the berth takes LOCAL's place (Jon, Oct 27).
	# A move under way steps from its target, so a quick double Tab is two steps.
	# Why: docs/why/Main.md#tab-round
	var at := ZoomLadder.lit_rank() if ZoomLadder.busy() else -1
	if at == ZoomLadder.LOCAL or at == ZoomLadder.STATION:
		Router.show_system()
	elif at == ZoomLadder.MAP:
		Router.show_starchart()
	elif at == ZoomLadder.CHART:
		if Router.docked:
			Router.show_station()
		else:
			Router.show_local()
	elif Router.current is SectorScreen or Router.current is StationScreen:
		Router.show_system()
	elif Router.current is SystemMapScreen:
		Router.show_starchart()
	elif Router.docked:
		Router.show_station()
	else:
		Router.show_local()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_ESCAPE:
		if _menu != null and _menu.in_settings():
			_menu.hide_settings()
		elif Router.final_loot and _menu == null:
			# Escape is DONE here, as on any popup: the menu would offer ABANDON on a won run.
			Router.finish_core_loot()
		elif Router.current is LauncherScreen:
			# Nothing to pause: the launcher IS the menu. Its Settings drawer is
			# the one thing Esc can close there.
			(Router.current as LauncherScreen).close_settings()
		elif Router.current is ChassisSelect and _menu == null:
			# Before the run: no escape menu, whose ABANDON would record a run
			# that never launched. The deck's popup, then the title.
			(Router.current as ChassisSelect).escape()
		else:
			toggle_menu()
	elif k.is_action_pressed(&"fullscreen"):
		# A binding (`Keys`), F11 out of the box. Escape above is not: it is
		# the way back from everything and is never moved.
		DisplaySettings.toggle_fullscreen()

## Silent until a sound is picked, rather than warning on every Esc.
func _open_test_salvage() -> void:
	var sector := Router.current as SectorScreen
	var n: MapGen.MapNode = Run.node_at()
	if sector == null or n == null:
		return
	var wreck := Run.new_wreck(n, DB.enemies[&"cutter"])
	var want: Array = [ModuleData.Rarity.COMMON, ModuleData.Rarity.RARE,
		ModuleData.Rarity.EPIC, ModuleData.Rarity.LEGENDARY]
	for r in want:
		for i in 400:
			# Commons drop shallower than tier 3 only (`LootGen.NO_COMMON_TIER`).
			var m := LootGen.roll_module(1 if r == ModuleData.Rarity.COMMON else 5)
			if m != null and m.rarity == r:
				wreck.items.append(m)
				break
	# EXOTIC and ARTIFACT come off the material table, which is where those
	# tiers actually live.
	for tier: StringName in [&"exotic", &"artifact"]:
		for row in MaterialTable.all():
			if StringName((row as Dictionary).get("tier", &"")) == tier:
				wreck.items.append(MaterialData.of(row))
				break
	wreck.items.append(CreditChit.of(120))
	print("[salvage] %s: %s" % [wreck.label,
		", ".join(wreck.items.map(func(m: HoldItem) -> String: return m.name))])
	sector._open_jetsam(wreck, "SALVAGE")

func _menu_sound(id: StringName) -> void:
	if ResourceLoader.exists(Audio.SFX_PATH % id):
		Audio.play(id, 0.03, 120)

## `animate` false when leaving the run, so the drawer does not slide over the title screen.
func toggle_menu(animate: bool = true) -> void:
	if _menu != null:
		if animate:
			_menu.close()
			_menu_sound(&"menu_close")
		else:
			_menu.queue_free()
		_menu = null
		return
	_menu_sound(&"menu_open")
	_menu = PauseMenu.new()
	_menu.theme = theme
	_overlay_layer().add_child(_menu)
	_menu.setup()
	_menu.resume_requested.connect(func() -> void: toggle_menu())
	# Abandon is recorded now: the run is over at the press, and quitting would lose it.
	# Why: docs/why/Main.md#abandon-and-quit
	_menu.quit_requested.connect(func() -> void:
		toggle_menu(false)
		# Skip if the run already ended, as `Router.new_run` does, or ABANDONED follows DIED.
		if not Run.dead and not Run.won:
			RunHistory.record(RunHistory.Outcome.ABANDONED, "Abandoned mid-run.")
		SaveGame.clear()
		# No hull is the boot state the title expects, and stops `new_run()` recording this twice.
		Run.hull = null
		# Out of a shared fight too, now: left for the next run to drop, it kept
		# a ghost in the party's crew until then (review, Nov 5).
		Router.drop_combat()
		Router.show_launcher())
	# Save and quit skips mid-combat: combat is outside the save and would bank spent hull.
	# Why: docs/why/Main.md#abandon-and-quit
	_menu.save_and_quit_requested.connect(func() -> void:
		# Combat is outside the save, so the arrival bookmark stands; a write would be unloadable.
		if not Router.in_combat():
			SaveGame.save()
		else:
			SaveGame.mark_fight(Router.current_fight)
		toggle_menu(false)
		# Drop the in-memory run once saved: the title's own galaxy would move this run's systems.
		# Why: docs/why/Main.md#abandon-and-quit
		Run.hull = null
		# Drop the party's fight and signals too, or partners stay on WAIT and CONTINUE resumes it.
		# Why: docs/why/Main.md#abandon-and-quit
		Router.drop_combat()
		Router.show_launcher())

## For shots: Settings in the escape drawer, scrolled once the rows have laid out.
func _show_keys() -> void:
	for i in 3:
		await get_tree().process_frame
	var panel: SettingsPanel = _find_settings_panel(self)
	if panel == null:
		return
	var page := panel.keys_page
	# A shot changes keys only in a file of its own, never the player's.
	var scratch := "user://bindshot.cfg"
	Keys.path = scratch
	for a in OS.get_cmdline_user_args():
		match a:
			"bindshot=listen":
				page.listen(&"ship_thrust", 1)
			"bindshot=clash":
				page.listen(&"ship_thrust", 0)
				page.offer(KEY_S)
			"bindshot=reset":
				# One key moved, so a RESET shows on its row, then the question.
				page.listen(&"ship_thrust", 1)
				page.offer(KEY_SPACE)
				page.ask_reset_all()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	await get_tree().process_frame
	panel.show_keys("bindshot=reset" in OS.get_cmdline_user_args())

## For `-- settings=motion`: the open Settings, scrolled to one section's head
## once the drawer has laid out.
func _show_section(id: StringName) -> void:
	for i in 3:
		await get_tree().process_frame
	var panel: SettingsPanel = _find_settings_panel(self)
	if panel != null:
		panel.show_section(id)

func _find_settings_panel(n: Node) -> SettingsPanel:
	if n is SettingsPanel:
		return n
	for c in n.get_children():
		var found := _find_settings_panel(c)
		if found != null:
			return found
	return null

func _open_settings() -> void:
	if _menu != null:
		_menu.show_settings()
		return
	if _settings != null:
		return
	_settings = SettingsMenu.new()
	_settings.theme = theme
	_overlay_layer().add_child(_settings)
	_settings.setup()
	_settings.closed.connect(_close_settings)

func _close_settings() -> void:
	if _settings == null:
		return
	_settings.close()
	_settings = null
