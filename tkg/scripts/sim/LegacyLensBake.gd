extends Node

## Traces the legacy hole's photon table once; rerun only if its constants change.


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var img := LegacyHole.trace_table()
	var ms := Time.get_ticks_msec() - t0
	DirAccess.make_dir_recursive_absolute(LegacyHole.TABLE_PATH.get_base_dir())
	var err := ResourceSaver.save(img, LegacyHole.TABLE_PATH, ResourceSaver.FLAG_COMPRESS)
	print("LEGACYLENSBAKE traced %dx%d in %d ms, saved %s: %s" % [img.get_width(), img.get_height(), ms,
		LegacyHole.TABLE_PATH, error_string(err)])
	get_tree().quit()
