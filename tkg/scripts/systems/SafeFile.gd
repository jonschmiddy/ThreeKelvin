class_name SafeFile
extends RefCounted

## Writes to `<path>.tmp`, then renames over `path`: a crash or a full disk leaves the old file whole.
## Why: docs/why/SafeFile.md#write-then-rename


## True when `path` now holds `text`. On failure the old file is untouched.
static func write_text(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("SafeFile: could not open %s for writing (%d)" % [
			tmp, FileAccess.get_open_error()])
		return false
	var stored := f.store_string(text)
	f.close()
	if stored:
		var err := DirAccess.rename_absolute(
			ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
		if err == OK:
			return true
		push_warning("SafeFile: could not move %s over %s (%d)" % [tmp, path, err])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	return false
