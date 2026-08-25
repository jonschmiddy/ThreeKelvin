extends Harness

## Every .gd in the project, loaded:
##   godot --headless --path . -- parseall
##
## `--check-only` DOES NOT SEE EVERY FILE, and that is the whole reason this
## exists. It reaches the scripts the scene tree pulls in; it does not reach the
## ones loaded by hand at the moment somebody runs them. Every out-of-band
## harness in scripts/sim is exactly that shape — `load(...)` inside a branch of
## Main that only fires when you pass its flag.
##
## So CoFightTest.gd sat un-parseable for five days. `--check-only` reported zero
## errors, `validate.sh` stayed green, and the only way to find out was to run
## the co-op harness by hand, which nothing in CI does. Three lines had gone in
## at column zero in the middle of an `if` body — the shape a heredoc leaves when
## it eats the indentation on the way in.
##
## Loading a GDScript compiles it, so a file that will not parse fails here.


func run() -> void:
	var files := _walk("res://scripts")
	print("
%d scripts under res://scripts" % files.size())
	for f in files:
		# TOUCH IT AND LET GODOT SPEAK. Three cleverer answers were tried here
		# and all three were wrong, which is most of what this file is for:
		#
		#   load(f) == null     waves a broken file through. A script that
		#                       will not parse still comes back AS a GDScript,
		#                       which is exactly why the failure this exists
		#                       for read "Nonexistent function 'new' in base
		#                       'GDScript'" instead of a null reference.
		#   can_instantiate()   answers a different question, and said no to
		#                       BotPilot, a file that parses perfectly.
		#   compile the source  every file carrying a `class_name` then
		#                       collides with its own registered global class.
		#
		# Godot itself prints "Parse Error" and "Failed to load script" when a
		# load fails. So the reliable check is simply to make sure every file
		# IS loaded and then to read what it said -- which validate.sh does by
		# grepping this run's log. All this loop owes it is the touching.
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
		name = d.get_next()
	d.list_dir_end()
	return out
