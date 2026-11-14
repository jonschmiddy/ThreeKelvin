class_name TestRun
extends RefCounted

## Anything after `--` a player would not type is a harness, and keeps off the player's files.
const PLAYER_ARGS := ["seed", "asrelease", "resume", "nolauncher", "keepwindow", "hints"]

static func active() -> bool:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s in PLAYER_ARGS or s.is_valid_int() or s.begins_with("style=") or s.begins_with("graphics="):
			continue
		return true
	return false


## A harness file this old (seconds) is swept.
const STALE_S := 86400

## One file per process: a shared file let parallel harnesses load each other's saves (Oct 12).
## Stale files go by age, not PID: `OS.is_process_running` ignores processes it did not start.
## Why: docs/why/TestRun.md#harness-scratch-files
static func scratch(stem: String, ext: String) -> String:
	if not _swept:
		_swept = true
		DirAccess.make_dir_recursive_absolute("user://harness")
		var now := int(Time.get_unix_time_from_system())
		for f in DirAccess.get_files_at("user://harness"):
			var p := "user://harness".path_join(f)
			if now - int(FileAccess.get_modified_time(p)) > STALE_S:
				DirAccess.remove_absolute(p)
	return "user://harness/%s_%d.%s" % [stem, OS.get_process_id(), ext]

static var _swept := false
