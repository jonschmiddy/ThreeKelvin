class_name PlaytestLogs
extends RefCounted

## One zip of named files from the game's own folder only, with the home path and name scrubbed.
## Nothing is sent anywhere. `build.txt` carries what a slow machine's report needs (Oct 27).
## Why: docs/why/PlaytestLogs.md#save-my-logs

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
		"settings: style %s, graphics %s (set by %s)" % [DisplaySettings.render_style, "LOW" if DisplaySettings.graphics_low else "HIGH",
			DisplaySettings.graphics_by if DisplaySettings.graphics_by != DisplaySettings.GFX_NOBODY else "nobody yet"],
		"look: %s" % DisplaySettings.look_name(DisplaySettings.screen_look),
		window_line(),
		"frames: cap %s, max_fps %d, vsync %s" % [
			"NONE" if DisplaySettings.frame_cap <= 0 else str(DisplaySettings.frame_cap),
			Engine.max_fps, vsync_name(DisplayServer.window_get_vsync_mode())],
		"driver: %s, %s, API %s" % [RenderingServer.get_current_rendering_driver_name(),
			RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_api_version()],
		"battery: %s" % power_state(),
	])
	return "\n".join(lines) + "\n"


## Records mode, size, pixel fit and screen scale, which decide how much a machine draws.
## Why: docs/why/PlaytestLogs.md#window-line
static func window_line() -> String:
	var win := DisplayServer.window_get_size()
	var k := maxi(1, mini(win.x / DisplaySettings.BASE.x, win.y / DisplaySettings.BASE.y))
	var on := DisplayServer.window_get_current_screen()
	return "window: %s, WINDOW SIZE %dx, %s px, picture %dx; screen %d scale %.2f, largest scale %.2f" % [
		DisplaySettings.mode_name(DisplaySettings.mode), DisplaySettings.window_scale,
		win, k, on + 1, DisplayServer.screen_get_scale(on), DisplayServer.screen_get_max_scale()]


static func vsync_name(m: int) -> String:
	match m:
		DisplayServer.VSYNC_DISABLED: return "off"
		DisplayServer.VSYNC_ENABLED: return "on"
		DisplayServer.VSYNC_ADAPTIVE: return "adaptive"
		DisplayServer.VSYNC_MAILBOX: return "mailbox"
	return str(m)


## Godot 4 has no power API, so a Mac is asked via `pmset -g batt`; a worn battery throttles.
static func power_state() -> String:
	if OS.get_name() == "macOS":
		var out: Array = []
		if OS.execute("/usr/bin/pmset", ["-g", "batt"], out) == 0 and not out.is_empty():
			# (less the battery's IOKit id: "-InternalBattery-0 (id=6815843)")
			var said := RegEx.create_from_string(" ?\\(id=\\d+\\)").sub(String(out[0]), "", true)
			said = said.replace("\t", " ").strip_edges()
			var parts := PackedStringArray()
			for line in said.split("\n", false):
				parts.append(line.strip_edges())
			if not parts.is_empty():
				return " | ".join(parts)
	return "not read on %s" % OS.get_name()


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
