@tool
extends EditorScript
## Dumps seeded Database content to .tres so content is inspector-editable. Run from the editor.
## Why: docs/why/export_resources.md#resource-export

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
