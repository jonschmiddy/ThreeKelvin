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

## Show the frame counter. Off by default.
##
## A SETTING RATHER THAN A DEV FLAG. It rode on `DevMode` for one commit, which
## meant a player could not see their frame rate without also unlocking the card
## gallery and the whole star chart -- and the counter is a diagnostic, not a
## cheat. The number a tester quotes when a screen feels choppy should not cost
## them the game's secrets.
static var fps_meter: bool = false

## THE VIEW KICKS WHEN YOU ARE HIT. Off is a real setting, not a nicety: shake
## is the single display effect people most often cannot play with, and a
## turn-based game has no excuse for making anyone put it down.
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
## WHETHER A CLICK CUTS THE JUMP SHORT.
##
## OFF, and that is the interesting default. The jump is seven seconds of
## departure, transit and arrival that the run has been building to, and a
## player who is holding the mouse while it plays -- which is everybody, they
## just clicked JUMP -- skips it by accident and never sees it again. So the
## skip is there for the player who has seen it enough, and they have to say so.
static var skip_jump: bool = false
## 0 is uncapped. The game is turn-based; a laptop should not run its fan for it.
static var frame_cap: int = 0

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


static func set_reduced_motion(on: bool) -> void:
	reduced_motion = on
	save()

static func set_frame_cap(fps: int) -> void:
	frame_cap = fps
	Engine.max_fps = fps
	save()

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
			# ONE PIXEL TALLER THAN THE SCREEN, and that pixel is the whole point.
			# A borderless window sized EXACTLY to the screen is what Windows
			# calls a fullscreen optimization: it hands the display over on every
			# focus change, which is the black flash when you click out to
			# another monitor and back. A window a pixel past the bottom edge is
			# an ordinary window to the compositor and still covers everything.
			#
			# TALLER, NOT SHORTER: the viewport scales by whole numbers, so a
			# window one pixel SHORT of 1080 would drop the game from 2x to 1x.
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
	# Load before writing. This used to save a fresh ConfigFile, which was
	# harmless while display was the only section — and would have silently
	# dropped the audio volumes every time the window was resized.
	cfg.load(PATH)
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
	cfg.set_value("display", "frame_cap", frame_cap)
	cfg.save(PATH)

static func load_and_apply() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		mode = cfg.get_value("display", "mode", int(Mode.WINDOWED)) as Mode
		window_scale = int(cfg.get_value("display", "window_scale", 1))
		screen = int(cfg.get_value("display", "screen", -1))
	fps_meter = bool(cfg.get_value("display", "fps_meter", false))
	screen_shake = bool(cfg.get_value("display", "screen_shake", true))
	colour_help = int(cfg.get_value("display", "colour_help", 0))
	high_contrast = bool(cfg.get_value("display", "high_contrast", false))
	brightness = int(cfg.get_value("display", "brightness", 0))
	screen_look = cfg.get_value("display", "screen_look", int(Look.CRT_GENTLE)) as Look
	reduced_motion = bool(cfg.get_value("display", "reduced_motion", false))
	skip_jump = bool(cfg.get_value("display", "skip_jump", false))
	frame_cap = int(cfg.get_value("display", "frame_cap", 0))
	Engine.max_fps = frame_cap
	apply()
