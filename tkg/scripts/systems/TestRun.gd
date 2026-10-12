class_name TestRun
extends RefCounted

## WAS THE GAME STARTED BY A HARNESS OR A TEST? Anything after `--` that a
## player would not type. A player's own arguments: `seed N` (replay a run),
## `asrelease`, `resume`, `nolauncher`, `keepwindow`, `hints`, and a style or
## graphics override. Everything else is a harness, and a harness keeps its
## hands off the player's files (SaveGame.path, RunHistory.path).
const PLAYER_ARGS := ["seed", "asrelease", "resume", "nolauncher", "keepwindow", "hints"]

static func active() -> bool:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s in PLAYER_ARGS or s.is_valid_int() or s.begins_with("style=") or s.begins_with("graphics="):
			continue
		return true
	return false


## A HARNESS'S OWN SCRATCH FILE, one per process:
## `user://harness/<stem>_<pid>.<ext>`.
##
## It was one file for every harness (`user://harness_run.save`), and the gate
## runs its harnesses side by side -- and other agents run theirs at the same
## time. So `subjecttest` saved its run, went to the title and pressed
## CONTINUE, and loaded whatever `savetest` or a render had just written there:
## another galaxy, another system, the ship "in orbit" of a world that system
## does not have (Oct 12: 4 failures in a gate, none run alone; reproduced 1 in
## 4 with `savetest` looping beside it). The "Parse JSON failed" that came and
## went in the gate was the same thing, a read half way through another
## process's write.
##
## Files not written for a day are deleted the first time any is asked for, so
## the folder holds only recent harnesses' files. BY AGE, NOT BY PID: Godot's
## `OS.is_process_running` only knows processes this one started, so on Windows
## it calls every other live harness gone -- the first version of this deleted
## a running `subjecttest`'s save under it (3 failures in 8 runs).
const STALE_S := 86400

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
