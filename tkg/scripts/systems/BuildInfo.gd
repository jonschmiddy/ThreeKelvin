class_name BuildInfo
extends RefCounted

## WHICH BUILD THIS IS, so a friend's report says what they played.
##
## Nothing here is typed by hand. `tools/export.sh` writes `res://build.json`
## ({version, commit, date}) just before it exports and deletes it after, so the
## file exists only inside an exported game: the version is
## `application/config/version` in project.godot, the commit is the short hash
## of what was exported. A run from source has no such file and says "dev".
##
## Shown small on the title screen (`LauncherScreen`) and at the foot of the
## pause menu (`PauseMenu`), printed at boot and at every new run into the log
## (`godot.log`, the file a friend sends), and stored with each flight record.

const PATH := "res://build.json"

static var _info: Dictionary = {}
static var _read := false


## The stamp's fields, or empty from source.
static func info() -> Dictionary:
	if not _read:
		_read = true
		if FileAccess.file_exists(PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			if parsed is Dictionary:
				_info = parsed
	return _info


## An exported build (it carries a stamp), as opposed to a run from source.
static func stamped() -> bool:
	return not info().is_empty()


## The short form for a corner of the screen: "0.1.0-alpha.1 · a1b2c3d", or "dev".
static func stamp() -> String:
	var i := info()
	if i.is_empty():
		return "dev"
	return "%s · %s" % [i.get("version", "?"), i.get("commit", "?")]


## The long form for the log: version, commit and when it was built.
static func line() -> String:
	var i := info()
	if i.is_empty():
		return "Three Kelvin dev (run from source)"
	return "Three Kelvin %s (commit %s, built %s)" % [
		i.get("version", "?"), i.get("commit", "?"), i.get("date", "?")]
