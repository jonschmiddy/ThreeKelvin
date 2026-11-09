class_name DevMode
extends RefCounted

## One flag for dev tools: judging pacing with them on measures the wrong thing.
## It exists only where the editor does, so exports never reach it. `-- asrelease` turns it off.
## Why: docs/why/DevMode.md#developer-mode

const PATH := "user://settings.cfg"

## Where the switch is saved. A harness points this at a scratch file, so the
## player's own settings are never read or written by a test.
static var path: String = PATH

## Whether this build has a workshop at all. Decided once, at load. The editor
## FEATURE, not is_debug_build(): a debug export is a debug build too.
static var available: bool = _detect(OS.get_cmdline_user_args(), OS.has_feature("editor"))

## Checked on every read and write, so nothing can leave the tools on where unavailable.
static var enabled: bool = available:
	get:
		return enabled and available
	set(v):
		enabled = v and available

## `editor` is passed in so `-- devtest` can ask what an export would: the editor always says yes.
## Why: docs/why/DevMode.md#detecting-dev-mode
static func _detect(args: PackedStringArray, editor: bool) -> bool:
	return editor and not "asrelease" in args

static func toggle() -> void:
	if not available:
		return
	enabled = not enabled
	save()
	# Long-lived screens rebuild on this: the HUD is built once and outlives every swap.
	Sig.dev_mode_changed.emit()

static func save() -> void:
	# Never a [dev] key where the switch does not exist. An export that wrote one
	# would leave a player's file saying something about a tool they never had.
	if not available:
		return
	var cfg := ConfigFile.new()
	# Load before writing, or this drops the display and audio sections. See the
	# same note in DisplaySettings.save().
	cfg.load(path)
	cfg.set_value("dev", "enabled", enabled)
	cfg.save(path)

static func load_settings() -> void:
	if not available:
		enabled = false
		return
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		enabled = bool(cfg.get_value("dev", "enabled", true))
