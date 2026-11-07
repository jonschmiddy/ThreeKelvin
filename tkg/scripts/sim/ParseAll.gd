extends Harness

## `--check-only` misses scripts loaded by hand: CoFightTest sat unparseable for five days.
## Why: docs/why/ParseAll.md#parse-all


func run() -> void:
	var files := _walk("res://scripts")
	print("
%d scripts under res://scripts" % files.size())
	for f in files:
		# Touch each file and read Godot's log: `load()` null and compiling both fail.
		# Why: docs/why/ParseAll.md#touch-and-read
		@warning_ignore("unused_variable")
		var touched := load(f)
	print("  touched %d scripts" % files.size())
	_ok("every script under res://scripts was reachable", files.size() > 0)
	verdict("parseall")


## Every .gd under `dir`, recursively. `.uid` files and directories are skipped.
func _walk(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var path := dir.path_join(name)
		if d.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_walk(path))
		elif name.ends_with(".gd"):
			out.append(path)
		elif name.ends_with(".gd.remap"):
			# Exports list `.gd.remap`, not `.gd`; without this the smoke test touched 0 scripts.
			out.append(path.trim_suffix(".remap"))
		name = d.get_next()
	d.list_dir_end()
	return out
