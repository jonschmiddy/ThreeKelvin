extends Node

## The legacy black hole's photon table, traced and written to
## `LegacyHole.TABLE_PATH`, so the game loads it instead of tracing it:
##   godot --headless --path . -- sheet=LegacyLensBake
## Run it again only if `LegacyHole`'s table constants change.


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var img := LegacyHole.trace_table()
	var ms := Time.get_ticks_msec() - t0
	DirAccess.make_dir_recursive_absolute(LegacyHole.TABLE_PATH.get_base_dir())
	var err := ResourceSaver.save(img, LegacyHole.TABLE_PATH, ResourceSaver.FLAG_COMPRESS)
	print("LEGACYLENSBAKE traced %dx%d in %d ms, saved %s: %s" % [img.get_width(), img.get_height(), ms,
		LegacyHole.TABLE_PATH, error_string(err)])
	get_tree().quit()
