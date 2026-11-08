class_name DisplaySettings
extends RefCounted

## Modes position against a chosen screen: borderless at (0,0) landed on the leftmost monitor.
## `max_window_scale()` stops the window growing until its title bar leaves the screen.
## Why: docs/why/DisplaySettings.md#display-modes

enum Mode { WINDOWED, BORDERLESS, FULLSCREEN }

const BASE := Vector2i(960, 540)
const PATH := "user://settings.cfg"
## Under a harness settings go to a scratch file, as every shot rewrote the player's settings.cfg,
## and RADIANT's safety could save SIMPLIFIED over their style.
## Why: docs/why/DisplaySettings.md#settings-path
static var HARNESS_PATH: String = TestRun.scratch("settings", "cfg") if TestRun.active() else "user://harness_settings.cfg"
static var path: String = HARNESS_PATH if TestRun.active() else PATH
## First-run flags use this process's scratch file under a
## harness, so a hint walk never marks the player's seen.
static func hints_path() -> String:
	return HARNESS_PATH if TestRun.active() else path
## Room left for the title bar and taskbar when sizing a windowed window.
const CHROME_ALLOWANCE := 96

static var mode: Mode = Mode.WINDOWED
static var window_scale: int = 1
static var screen: int = -1          ## -1 means "not chosen yet"; resolves to primary

## A setting, not a dev flag: on `DevMode` a player could not see their frame rate
## without unlocking the card gallery and the whole star chart.
## Why: docs/why/DisplaySettings.md#frame-counter
static var fps_meter: bool = false

## Off is a real setting: shake is the display effect people most often cannot play with.
static var screen_shake: bool = true

## WHAT THE SCREEN DOES TO THE PICTURE. All of it is one shader over the
## finished frame (GameShell); these are the knobs a player sees.
enum Look { FLAT, SCANLINES, CRT_GENTLE, CRT, CRT_ARCADE }
## 0 off, 1 deuteranopia, 2 protanopia, 3 tritanopia. Not a simulation: the
## colour difference those eyes cannot see is pushed into brightness and blue.
static var colour_help: int = 0
static var high_contrast: bool = false
## -1 darker, 0 as made, +1 brighter. Steps rather than a slider, like volume.
static var brightness: int = 0
## ON BY DEFAULT, at Jon's call: the gentle tube is how the game is meant to
## look, and FLAT is the option for anyone who does not want it.
static var screen_look: Look = Look.CRT_GENTLE
## Off turns every animation in the game off at the source: `Router.animating`
## is what every screen asks before it moves anything.
static var reduced_motion: bool = false
## Off by default: the jump is seven seconds the run builds to, and a player holding the mouse
## after JUMP skips it by accident and never sees it.
## Why: docs/why/DisplaySettings.md#skip-jump
static var skip_jump: bool = false
## THE AUTOPILOT'S FLIGHT (Jon, Nov 5, "AUTOPILOT: DIRECT . CURVED"): CURVED,
## the default, swings wide round the stars as an orbit falls ("the curved
## maneuvers are AESTHETIC"); DIRECT flies ruling 21's straighter line. Each
## ship flies its own pilot's setting (`ShipFlight.flight_opts`).
static var autopilot: StringName = &"curved"
## 0 is uncapped. The game is turn-based; a laptop should not run its fan for it.
static var frame_cap: int = 0
## 30, 60 and 120 joined NONE on Jon's call (Oct 27, perf C3): on a slow machine V-Sync gives
## a jumpy mix of 60 and 30, and a 30 cap paces it evenly. Opt-in; NONE stays default.
## Why: docs/why/DisplaySettings.md#frame-cap
const FRAME_CAPS: Array[int] = [0, 30, 60, 120]
## The cap VSYNC OFF brings with it when FRAME CAP is NONE.
const VSYNC_OFF_CAP := 60
## V-Sync goes off only with a cap (Jon, Oct 27, C3): uncapped, a turn-based screen
## draws as fast as it can, which is just heat.
## Why: docs/why/DisplaySettings.md#v-sync
static var vsync: bool = true
## -1 if never set, so `--disable-vsync` and a bench's
## own VSYNC_DISABLED still hold under a harness.
static var applied_vsync: int = -1

## Four styles in Settings' order (Jon, 2026-10-05); SIMPLIFIED is the default for now.
## All share SIMPLIFIED's animations and its black hole (`LegacyHole`).
## Why: docs/why/DisplaySettings.md#render-styles
const STYLES: Array[StringName] = [&"legacy", &"simplified", &"painted", &"radiant"]
## The default, and what anything unknown or not built falls back to.
const DEFAULT_STYLE := &"simplified"
## Only styles with a renderer; the STYLE row appears once there are two. Add a style here only.
const BUILT: Array[StringName] = [&"legacy", &"simplified", &"painted", &"radiant"]
static var render_style: StringName = DEFAULT_STYLE
## GRAPHICS LOW: the cheaper path every style's renderer keeps.
static var graphics_low: bool = false
## Records who set GRAPHICS (Jon, Oct 27, C1): the file could not tell a HIGH choice from never
## looking. An old file counts HIGH as NOBODY, which is every alpha player on the default.
## Why: docs/why/DisplaySettings.md#graphics-ownership
const GFX_NOBODY := ""
const GFX_MACHINE := "machine"
const GFX_PLAYER := "player"
static var graphics_by: String = GFX_NOBODY
## The machine's pick under a picture already up leaves it on its old pass until it is rebuilt.
static var _low_held := false
## Harness `style=` and `graphics=` live in memory only,
## as `apply()` ends in `save()` and rewrote the file.
static var _harness_style := false
static var _harness_low := false
static var _file_style: StringName = DEFAULT_STYLE
static var _file_low := false
## A harness stand-in for the command line, read by
## `load_and_apply` in its place; empty means the real one.
static var harness_args := PackedStringArray()

static func style_built(s: StringName) -> bool:
	return BUILT.has(s)

static func style_name(s: StringName) -> String:
	match s:
		&"legacy": return "LEGACY"
		&"painted": return "PAINTED"
		&"radiant": return "RADIANT"
		_: return "SIMPLIFIED"

## Built styles in Settings' order.
static func built_styles() -> Array[StringName]:
	var out: Array[StringName] = []
	for s in STYLES:
		if style_built(s):
			out.append(s)
	return out

## Unknown or unbuilt values fall to the default;
## an old file saying legacy meant what is now SIMPLIFIED.
static func valid_style(v: Variant) -> StringName:
	var s := StringName(str(v))
	return s if style_built(s) else DEFAULT_STYLE

## The style a settings file asks for, as one that can be drawn.
static func style_in(cfg: ConfigFile) -> StringName:
	return valid_style(cfg.get_value("display", "render_style", String(DEFAULT_STYLE)))

## Choose a style. False, and nothing changes, for one that is not built. The
## chart and the sector map rebuild on `Sig.render_style_changed`.
static func set_render_style(s: StringName) -> bool:
	if not style_built(s):
		return false
	if s == render_style:
		return true
	render_style = s
	_harness_style = false  # the player chose it: it is theirs to keep
	# Choosing RADIANT again tries it again: the safety held it off for the session
	# and nothing let it go, so the setting said RADIANT over SIMPLIFIED.
	# Why: docs/why/DisplaySettings.md#radiant-safety
	if s == &"radiant":
		ChartRadiant.fell_back = false
	save()
	Sig.render_style_changed.emit()
	return true


## Fall back keeps the setting but rebuilds nothing now: a style switched under a still view
## read as the frame dimming by itself (16.9 to 13.2).
## Why: docs/why/DisplaySettings.md#radiant-safety
static func fall_back_style(s: StringName) -> void:
	if not style_built(s) or s == render_style:
		return
	render_style = s
	save()


## The style was put there by a harness's `style=` (not the player's to keep,
## and never overruled by RADIANT's safety unless it asks: `radiantprobe=MS`).
static func harness_style() -> bool:
	return _harness_style


## A launch that forced the look with `style=` or `graphics=`: the machine's
## pick neither measures it nor overrules it (`GpuProbe.wanted`).
static func harness_forced() -> bool:
	return _harness_style or _harness_low


## LOW on lets RADIANT try again, as what was too heavy on HIGH may hold on LOW.
## Any press makes it the player's own, and the machine never picks again.
## Why: docs/why/DisplaySettings.md#graphics-ownership
static func set_graphics_low(on: bool) -> void:
	if on == graphics_low and not _harness_low and graphics_by == GFX_PLAYER and not _low_held:
		return
	graphics_low = on
	graphics_by = GFX_PLAYER
	_low_held = false
	_harness_low = false  # the player chose it: it is theirs to keep
	if on:
		ChartRadiant.fell_back = false
	save()
	Sig.render_style_changed.emit()


## The machine's pick rebuilds nothing, like RADIANT's fall-back; Settings redraws its row,
## or a drawer with HIGH marked over a LOW pick could not be pressed back to HIGH.
## Why: docs/why/DisplaySettings.md#graphics-ownership
static func machine_pick(low: bool) -> void:
	if graphics_by != GFX_NOBODY or harness_forced():
		return
	graphics_by = GFX_MACHINE
	if low != graphics_low:
		graphics_low = low
		_low_held = true
	if low:
		ChartRadiant.fell_back = false
	save()
	Sig.graphics_picked.emit()


## Whether LOW is only the adapter's hint: Settings
## words it differently, as a chip name is no measure.
static func low_by_hint() -> bool:
	return graphics_low and graphics_by == GFX_NOBODY and not _harness_low


## Whether a picture up should keep the pass it was built with (`_low_held`).
static func low_held() -> bool:
	return _low_held


## The machine picked LOW and the player has not since; Settings says so beside the row.
static func low_by_machine() -> bool:
	return graphics_low and graphics_by != GFX_PLAYER and not _harness_low


## Who set GRAPHICS, as a settings file says (`graphics_by`). A file from before
## the key: LOW was pressed, HIGH may never have been.
static func graphics_by_in(cfg: ConfigFile) -> String:
	if not cfg.has_section_key("display", "graphics_by"):
		return GFX_PLAYER if bool(cfg.get_value("display", "graphics_low", false)) else GFX_NOBODY
	var v := str(cfg.get_value("display", "graphics_by", GFX_NOBODY))
	# (anything else is a hand-edited file: never overruled)
	return v if v in [GFX_NOBODY, GFX_MACHINE, GFX_PLAYER] else GFX_PLAYER

static func look_name(l: Look) -> String:
	match l:
		Look.SCANLINES: return "LINES"
		Look.CRT_GENTLE: return "CRT"
		Look.CRT: return "CRT+"
		Look.CRT_ARCADE: return "ARCADE"
		_: return "FLAT"

static func colour_help_name(i: int) -> String:
	match i:
		1: return "RED-GREEN"
		2: return "RED-GREEN 2"
		3: return "BLUE-YELLOW"
		_: return "OFF"

static func gamma_value() -> float:
	match brightness:
		-1: return 0.85
		1: return 1.2
		_: return 1.0

static func set_colour_help(i: int) -> void:
	colour_help = clampi(i, 0, 3)
	GameShell.refresh()
	save()

static func set_high_contrast(on: bool) -> void:
	high_contrast = on
	GameShell.refresh()
	save()

static func set_brightness(step: int) -> void:
	brightness = clampi(step, -1, 1)
	GameShell.refresh()
	save()

static func set_look(l: Look) -> void:
	screen_look = l
	GameShell.refresh()
	save()

static func set_skip_jump(on: bool) -> void:
	skip_jump = on
	save()


static func set_autopilot(p: StringName) -> void:
	autopilot = &"direct" if p == &"direct" else &"curved"
	save()


static func set_reduced_motion(on: bool) -> void:
	reduced_motion = on
	save()

## FRAME CAP from Settings. NONE while V-Sync is off turns V-Sync back on:
## off is only ever allowed with a cap.
static func set_frame_cap(fps: int) -> void:
	frame_cap = maxi(fps, 0)
	Engine.max_fps = frame_cap
	if frame_cap == 0 and not vsync:
		vsync = true
		_apply_vsync()
	save()

## VSYNC from Settings. OFF with FRAME CAP at NONE also sets the cap to
## `VSYNC_OFF_CAP`, so the game is never left drawing unlimited.
static func set_vsync(on: bool) -> void:
	vsync = on
	if not on and frame_cap == 0:
		frame_cap = VSYNC_OFF_CAP
		Engine.max_fps = frame_cap
	_apply_vsync()
	save()

## Hand `vsync` to the window, and note it in `applied_vsync`.
static func _apply_vsync() -> void:
	applied_vsync = DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(applied_vsync as DisplayServer.VSyncMode)

static func set_screen_shake(on: bool) -> void:
	screen_shake = on
	save()

static func mode_name(m: Mode) -> String:
	match m:
		Mode.WINDOWED: return "WINDOWED"
		Mode.BORDERLESS: return "BORDERLESS"
		_: return "FULLSCREEN"

static func mode_blurb(m: Mode) -> String:
	match m:
		Mode.WINDOWED: return "A real window you can move and close."
		Mode.BORDERLESS: return "Fills the chosen monitor. Alt-tabs instantly."
		_: return "Exclusive fullscreen: best frame pacing."

## Monitors can be unplugged between sessions, so a stored index is never trusted.
static func safe_screen() -> int:
	var count := DisplayServer.get_screen_count()
	if screen < 0 or screen >= count:
		return DisplayServer.get_primary_screen()
	return screen

static func screen_label(i: int) -> String:
	var s := DisplayServer.screen_get_size(i)
	var tag := " *" if i == DisplayServer.get_primary_screen() else ""
	return "%d  %dx%d%s" % [i + 1, s.x, s.y, tag]

## Retina stops at 2X (Jon, Oct 27, C2): 3X is 4.7 million pixels and about four full-window
## passes a frame. A saved 3X window opens at 2X; borderless and fullscreen still fill the screen.
## Why: docs/why/DisplaySettings.md#retina-cap
const RETINA_MAX_SCALE := 2

## The screen as `-- menutest` sees it, so the cap is tested
## on non-Retina machines; ZERO and -1 ask the real one.
static var test_screen := Vector2i.ZERO
static var test_retina := -1

## Retina is judged by the largest backing scale of any screen, as Godot's macOS pixels use it.
static func retina() -> bool:
	if test_retina >= 0:
		return test_retina == 1
	return OS.get_name() == "macOS" and DisplayServer.screen_get_max_scale() > 1.0

## The monitor the window opens on, in pixels.
static func _screen_px() -> Vector2i:
	if test_screen != Vector2i.ZERO:
		return test_screen
	return DisplayServer.screen_get_size(safe_screen())

## Largest whole-number scale that still leaves a window on a screen of `px`
## its chrome. No Retina cap: `max_window_scale` adds that.
static func fit_scale(px: Vector2i) -> int:
	var by_w := int(floor(float(px.x) / float(BASE.x)))
	var by_h := int(floor(float(px.y - CHROME_ALLOWANCE) / float(BASE.y)))
	return maxi(1, mini(by_w, by_h))

## Largest window scale offered, measured against the monitor it will actually
## open on: the biggest that fits, and never past 2X on a Retina Mac.
static func max_window_scale() -> int:
	var top := fit_scale(_screen_px())
	return mini(top, RETINA_MAX_SCALE) if retina() else top

## Whether the Retina cap took a window size away on this screen, for the note
## under Settings' WINDOW SIZE.
static func retina_capped() -> bool:
	return retina() and fit_scale(_screen_px()) > RETINA_MAX_SCALE

static func apply() -> void:
	var idx := safe_screen()
	var origin := DisplayServer.screen_get_position(idx)
	var extent := DisplayServer.screen_get_size(idx)

	match mode:
		Mode.WINDOWED:
			window_scale = clampi(window_scale, 1, max_window_scale())
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			var size := BASE * window_scale
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(origin + (extent - size) / 2)
		Mode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_position(origin)
			# One pixel taller than the screen: an exact-fit borderless window gets Windows'
			# fullscreen optimization (black flash). Taller, as shorter than 1080 drops to 1x.
			# Why: docs/why/DisplaySettings.md#borderless-window
			DisplayServer.window_set_size(extent + Vector2i(0, 1))
		Mode.FULLSCREEN:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			# The window has to be on the target screen before going exclusive,
			# or it takes over whichever screen it was already sitting on.
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_position(origin + Vector2i(40, 40))
			DisplayServer.window_set_current_screen(idx)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	save()

static func set_mode(m: Mode) -> void:
	mode = m
	apply()

static func set_scale(s: int) -> void:
	window_scale = clampi(s, 1, max_window_scale())
	mode = Mode.WINDOWED
	apply()

## Toggle the frame counter. Announced so a meter already on screen can react
## without the settings menu knowing it exists.
static func set_fps_meter(on: bool) -> void:
	fps_meter = on
	save()
	Sig.fps_meter_changed.emit(on)


static func set_screen(i: int) -> void:
	screen = i
	apply()

## F11 leaves the mode picker alone and just flips between a window and the
## screen, which is what people expect the key to do.
static func toggle_fullscreen() -> void:
	set_mode(Mode.WINDOWED if mode != Mode.WINDOWED else Mode.FULLSCREEN)

static func save() -> void:
	var cfg := ConfigFile.new()
	# Load before writing, or a fresh ConfigFile would drop the audio volumes on every resize.
	cfg.load(path)
	cfg.set_value("display", "mode", int(mode))
	cfg.set_value("display", "window_scale", window_scale)
	cfg.set_value("display", "screen", safe_screen())
	cfg.set_value("display", "fps_meter", fps_meter)
	cfg.set_value("display", "screen_shake", screen_shake)
	cfg.set_value("display", "colour_help", colour_help)
	cfg.set_value("display", "high_contrast", high_contrast)
	cfg.set_value("display", "brightness", brightness)
	cfg.set_value("display", "screen_look", int(screen_look))
	cfg.set_value("display", "reduced_motion", reduced_motion)
	cfg.set_value("display", "skip_jump", skip_jump)
	cfg.set_value("display", "autopilot", String(autopilot))
	cfg.set_value("display", "frame_cap", frame_cap)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("display", "render_style", String(_file_style if _harness_style else render_style))
	# (nobody's yet: the file keeps the default, whatever the adapter's hint drew
	# with this launch; the hint is asked again until the measure decides)
	cfg.set_value("display", "graphics_low", _file_low if _harness_low
		else (graphics_low if graphics_by != GFX_NOBODY else false))
	cfg.set_value("display", "graphics_by", graphics_by)
	cfg.save(path)

## With no settings file, a 1080p screen opens BORDERLESS, as the biggest window there is 1x
## (release check, Oct 18; Jon: A). Not under a harness unless `first_launch_in_harness` is set.
## Why: docs/why/DisplaySettings.md#first-launch
static var first_launch_in_harness := false

static func first_launch_window(top: int = -1) -> void:
	if top < 1:
		top = max_window_scale()
	if top <= 1:
		mode = Mode.BORDERLESS
		window_scale = 1
	else:
		mode = Mode.WINDOWED
		window_scale = top

static func load_and_apply() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		mode = cfg.get_value("display", "mode", int(Mode.WINDOWED)) as Mode
		window_scale = int(cfg.get_value("display", "window_scale", 1))
		screen = int(cfg.get_value("display", "screen", -1))
	elif first_launch_in_harness or not TestRun.active():
		# A harness's scratch file is always new; its window stays as it was.
		first_launch_window()
	fps_meter = bool(cfg.get_value("display", "fps_meter", false))
	screen_shake = bool(cfg.get_value("display", "screen_shake", true))
	colour_help = int(cfg.get_value("display", "colour_help", 0))
	high_contrast = bool(cfg.get_value("display", "high_contrast", false))
	brightness = int(cfg.get_value("display", "brightness", 0))
	screen_look = cfg.get_value("display", "screen_look", int(Look.CRT_GENTLE)) as Look
	reduced_motion = bool(cfg.get_value("display", "reduced_motion", false))
	skip_jump = bool(cfg.get_value("display", "skip_jump", false))
	autopilot = &"direct" if String(cfg.get_value("display", "autopilot", "curved")) == "direct" else &"curved"
	frame_cap = maxi(int(cfg.get_value("display", "frame_cap", 0)), 0)
	# A file from before VSYNC has no key: ON, as it always was. OFF with no
	# cap is never kept: V-Sync comes back on.
	vsync = bool(cfg.get_value("display", "vsync", true)) or frame_cap == 0
	render_style = style_in(cfg)
	graphics_low = bool(cfg.get_value("display", "graphics_low", false))
	graphics_by = graphics_by_in(cfg)
	_low_held = false
	_file_style = render_style
	_file_low = graphics_low
	Engine.max_fps = frame_cap
	# ON is what the window already has, so it is only handed over when it
	# changes something: OFF, or ON again after this game turned it off.
	if not vsync or applied_vsync == DisplayServer.VSYNC_DISABLED:
		_apply_vsync()
	# Harness `style=` and `graphics=` apply in memory only;
	# an unbuilt style draws as LEGACY and says so.
	for a in (harness_args if not harness_args.is_empty() else OS.get_cmdline_user_args()):
		var arg := a as String
		if arg.begins_with("style="):
			_harness_style = true
			render_style = valid_style(arg.substr(6))
			if String(render_style) != arg.substr(6):
				push_warning("style=%s is not built; drawing %s" % [arg.substr(6), style_name(DEFAULT_STYLE)])
		elif arg.begins_with("graphics="):
			_harness_low = true
			graphics_low = arg.substr(9) == "low"
	# A weak Intel adapter draws LOW from the first picture,
	# in memory, until the title's sky measures it.
	if GpuProbe.wanted() and GpuProbe.hint_weak():
		graphics_low = true
	# `keepwindow` leaves the window where the command line
	# put it; Godot strips its flags, so the run says so.
	if "keepwindow" in OS.get_cmdline_user_args():
		leave_launch_window()
		return
	var from_launch := in_launch_window()
	apply()
	# One dark frame fills the new area, as the compositor
	# leaves junk until the title's first frame.
	if from_launch:
		RenderingServer.force_draw()


## The launch window is a small borderless one in the centre (Jon, Oct 20) while scripts load.
## Mode is not tested: a screen-sized `--resolution` makes Windows report borderless as fullscreen.
## Why: docs/why/DisplaySettings.md#launch-window
static func in_launch_window() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if not bool(ProjectSettings.get_setting("display/window/size/borderless", false)):
		return false
	return DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)

## Harnesses keep their old framed 1920x1080 window; their own `--resolution` or `--position` wins.
const HARNESS_WINDOW := Vector2i(1920, 1080)

static func leave_launch_window() -> void:
	if not in_launch_window():
		return
	# Read before the frame comes back: dropping the flag keeps the outer rect,
	# so the picture inside shrinks by the frame.
	var was := DisplayServer.window_get_size()
	var at := DisplayServer.window_get_position()
	var launch := Vector2i(
		int(ProjectSettings.get_setting("display/window/size/window_width_override")),
		int(ProjectSettings.get_setting("display/window/size/window_height_override")))
	# Frame first, then mode: a screen-sized borderless
	# window is fullscreen to Windows and ignores WINDOWED.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if was != launch:
		DisplayServer.window_set_size(was)
		DisplayServer.window_set_position(at)
		return
	var idx := DisplayServer.window_get_current_screen()
	DisplayServer.window_set_size(HARNESS_WINDOW)
	if "--position" in OS.get_cmdline_args():
		DisplayServer.window_set_position(at)
	else:
		DisplayServer.window_set_position(DisplayServer.screen_get_position(idx)
			+ (DisplayServer.screen_get_size(idx) - HARNESS_WINDOW) / 2)
