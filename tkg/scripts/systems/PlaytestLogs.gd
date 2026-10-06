class_name PlaytestLogs
extends RefCounted

## SAVE MY LOGS: one zip a friend can drag into the chat.
##
## Without it, sending what went wrong means finding a hidden AppData folder.
## So one button (Settings' PLAYTEST row, and the game-over panel) writes ONE
## zip to the Desktop -- or into the game's own folder if the Desktop cannot be
## written -- and opens the folder with it selected.
##
## WHAT IS IN IT, BY NAME, AND NOTHING ELSE: this session's `godot.log` and the
## one before it, `settings.cfg`, `run.save` if a run is suspended, the flight
## record (`history.json`), and `build.txt` -- which build this is, the OS and
## the graphics card. Every one of them is read from the game's own user folder;
## nothing outside it is ever opened, and a developer's folder full of harness
## pictures stays out because nothing is gathered by listing a folder except
## the logs, and only `.log` files from there.
##
## IN THE LOG COPIES the home folder's path becomes `~` and the account name
## goes too: logs can carry absolute paths (an engine warning about a file names
## it), and a friend's user name is nobody else's business.
##
## NOTHING IS SENT ANYWHERE. It is a file on their own disk.

## Where a test writes instead of the Desktop (`-- menutest`); empty is real.
static var dest_override := ""
## The last zip written this session, for the screen to point at.
static var last_path := ""


## Write the zip. Returns {ok, path, files, where, error}: `where` is "desktop"
## or "user folder", for a line that says where to look.
static func save_bundle() -> Dictionary:
	var stamp := Time.get_datetime_string_from_system(false, false).replace(":", "").replace("T", "-")
	var build := BuildInfo.stamp().replace(" · ", "-").replace(" ", "_")
	var name := "ThreeKelvin-logs-%s-%s.zip" % [build, stamp.substr(0, 15)]
	var tries: Array = []
	if dest_override != "":
		tries.append([dest_override, "test folder"])
	else:
		var desk := OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
		if desk != "":
			tries.append([desk, "desktop"])
		tries.append([ProjectSettings.globalize_path("user://playtest"), "user folder"])
	for t: Array in tries:
		var dir: String = t[0]
		DirAccess.make_dir_recursive_absolute(dir)
		var path := dir.path_join(name)
		var zp := ZIPPacker.new()
		if zp.open(path) != OK:
			continue
		var files := PackedStringArray()
		for e: Array in _entries():
			if zp.start_file(String(e[0])) != OK:
				continue
			zp.write_file(e[1] as PackedByteArray)
			zp.close_file()
			files.append(String(e[0]))
		zp.close()
		last_path = path
		return {ok = true, path = path, files = files, where = t[1], error = ""}
	return {ok = false, path = "", files = PackedStringArray(), where = "", error = "Could not write the zip to the Desktop or the game's folder."}


## Open the folder with the zip selected.
static func show_in_folder(path: String) -> void:
	if path != "":
		OS.shell_show_in_file_manager(path)


## [name in the zip, bytes], for every file that exists.
static func _entries() -> Array:
	var out: Array = []
	var logs := _logs()
	for p: String in logs:
		out.append(["logs/" + p.get_file(), _scrub(FileAccess.get_file_as_string(p)).to_utf8_buffer()])
	for pair: Array in [["settings.cfg", DisplaySettings.path], ["run.save", SaveGame.path],
			["history.json", RunHistory.path]]:
		var src: String = pair[1]
		if _inside_user(src) and FileAccess.file_exists(src):
			out.append([pair[0], FileAccess.get_file_as_bytes(src)])
	out.append(["build.txt", _build_txt().to_utf8_buffer()])
	return out


## This session's log and the one before it (Godot keeps the last few, renamed
## with their date, in user://logs).
static func _logs() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := "user://logs"
	if FileAccess.file_exists(dir.path_join("godot.log")):
		out.append(dir.path_join("godot.log"))
	var older := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".log") and f != "godot.log":
			older.append(f)
	older.sort()
	if older.size() > 0:
		out.append(dir.path_join(older[older.size() - 1]))
	return out


static func _build_txt() -> String:
	var lines := PackedStringArray([
		BuildInfo.line(),
		"saved %s" % Time.get_datetime_string_from_system(false, true),
		"%s %s" % [OS.get_name(), OS.get_version()],
		"graphics: %s (%s)" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()],
		"screen: %s, window %s" % [DisplayServer.screen_get_size(), DisplayServer.window_get_size()],
		"settings: style %s, graphics %s" % [DisplaySettings.render_style, "LOW" if DisplaySettings.graphics_low else "HIGH"],
	])
	return "\n".join(lines) + "\n"


## A user:// path, or nothing: the bundle never reads outside the game's folder.
static func _inside_user(p: String) -> bool:
	return p.begins_with("user://")


## The home folder and the account name, out of a log.
static func _scrub(s: String) -> String:
	var home := OS.get_environment("USERPROFILE")
	if home == "":
		home = OS.get_environment("HOME")
	if home != "":
		s = s.replace(home, "~").replace(home.replace("\\", "/"), "~")
	var who := OS.get_environment("USERNAME")
	if who == "":
		who = OS.get_environment("USER")
	if who.length() >= 3:
		s = s.replace("/Users/" + who, "/Users/~").replace("\\Users\\" + who, "\\Users\\~")
	return s
