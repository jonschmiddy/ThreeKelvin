class_name DisplaySettings
extends RefCounted

## Display mode and monitor, persisted to user://settings.cfg.
##
## Every mode positions itself against a chosen screen rather than the desktop
## origin. Borderless used to sit at (0,0), which is the top-left of the whole
## virtual desktop, so on a multi-monitor setup it always landed on whichever
## monitor happens to be leftmost.
##
## The viewport is 960x540 and scales by whole numbers only, so a windowed size
## is always an exact multiple. max_window_scale() is what stops the window from
## growing to the height of the screen and pushing its own title bar out of
## reach — a trap this project hit once already.

enum Mode { WINDOWED, BORDERLESS, FULLSCREEN }

const BASE := Vector2i(960, 540)
const PATH := "user://settings.cfg"
## Room left for the title bar and taskbar when sizing a windowed window.
const CHROME_ALLOWANCE := 96

static var mode: Mode = Mode.WINDOWED
static var window_scale: int = 1
static var screen: int = -1          ## -1 means "not chosen yet"; resolves to primary

static func mode_name(m: Mode) -> String:
	match m:
		Mode.WINDOWED: return "WINDOWED"
		Mode.BORDERLESS: return "BORDERLESS"
		_: return "FULLSCREEN"

static func mode_blurb(m: Mode) -> String:
	match m:
		Mode.WINDOWED: return "A real window you can move and close."
		Mode.BORDERLESS: return "Fills the chosen monitor. Alt-tabs instantly."
		_: return "Exclusive fullscreen. Best frame pacing."

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

## Largest whole-number scale that still leaves the window its chrome, measured
## against the monitor it will actually open on.
static func max_window_scale() -> int:
	var size := DisplayServer.screen_get_size(safe_screen())
	var by_w := int(floor(float(size.x) / float(BASE.x)))
	var by_h := int(floor(float(size.y - CHROME_ALLOWANCE) / float(BASE.y)))
	return maxi(1, mini(by_w, by_h))

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
			DisplayServer.window_set_size(extent)
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

static func set_screen(i: int) -> void:
	screen = i
	apply()

## F11 leaves the mode picker alone and just flips between a window and the
## screen, which is what people expect the key to do.
static func toggle_fullscreen() -> void:
	set_mode(Mode.WINDOWED if mode != Mode.WINDOWED else Mode.FULLSCREEN)

static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "mode", int(mode))
	cfg.set_value("display", "window_scale", window_scale)
	cfg.set_value("display", "screen", safe_screen())
	cfg.save(PATH)

static func load_and_apply() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		mode = cfg.get_value("display", "mode", int(Mode.WINDOWED)) as Mode
		window_scale = int(cfg.get_value("display", "window_scale", 1))
		screen = int(cfg.get_value("display", "screen", -1))
	apply()
