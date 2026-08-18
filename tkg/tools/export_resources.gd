@tool
extends EditorScript
## Dumps the seeded Database content to .tres files so modules, hulls and
## enemies become inspector-editable assets instead of code.
##
## Run from the Godot editor: File > Run (with this script open).
## After exporting, point Database at the folders with ResourceLoader if you
## prefer .tres as the source of truth.

func _run() -> void:
	var db := load("res://scripts/autoload/Database.gd").new()
	db._ready()
	var counts := {modules = 0, hulls = 0, enemies = 0, manufacturers = 0}

	for id in db.modules.keys():
		var path := "res://resources/modules/%s.tres" % id
		if ResourceSaver.save(db.modules[id], path) == OK:
			counts.modules += 1
	for id in db.enemies.keys():
		var path2 := "res://resources/enemies/%s.tres" % id
		if ResourceSaver.save(db.enemies[id], path2) == OK:
			counts.enemies += 1
	for id in db.manufacturers.keys():
		var path3 := "res://resources/manufacturers/%s.tres" % id
		if ResourceSaver.save(db.manufacturers[id], path3) == OK:
			counts.manufacturers += 1
	for i in db.hull_frames.size():
		var h: HullData = db.hull_frames[i]
		var path4 := "res://resources/hulls/%s.tres" % h.name.to_snake_case()
		if ResourceSaver.save(h, path4) == OK:
			counts.hulls += 1

	print("Exported: %s" % str(counts))
	print("Resources written to res://resources/. Reload the project to see them.")
