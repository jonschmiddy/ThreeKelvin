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
