extends Node

## Every hull in `DB.hull_frames`, at every grade, declares where each of its parts is on its picture
## (`HullParts`), and every point lands on the picture's own pixels: `-- sheet=HullPartsTest` (headless).
## Why: docs/why/HullParts.md#hull-parts

var h := Harness.new()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	var keys := {}
	var missing: Array[String] = []
	var off: Array[String] = []
	var checked := 0
	for fr: HullData in DB.hull_frames:
		for tier in HullData.TIER_NAMES.size():
			var key := DB.hull_art_key(fr.weight, tier, fr.manufacturer)
			if key == "" or keys.has(key):
				continue
			keys[key] = true
			var d := HullParts.of(key)
			var img := _picture(fr, tier)
			for part: StringName in ShipParts.SPOTS:
				if not d.has(part):
					missing.append("%s %s" % [key, part])
					continue
				checked += 1
				var p: Vector2i = d[part]
				if img == null or p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height() \
						or img.get_pixel(p.x, p.y).a < 0.5:
					off.append("%s %s at %s" % [key, part, p])
	print("  %d hull pictures, %d part spots" % [keys.size(), checked])
	for m in missing:
		print("  missing: %s" % m)
	for o in off:
		print("  off the picture: %s" % o)
	h._ok("every hull picture declares every part (%d missing)" % missing.size(), missing.is_empty() and keys.size() > 0)
	h._ok("every part spot is on the picture's own pixels (%d off)" % off.size(), off.is_empty())
	h.verdict("hullpartstest")
	get_tree().quit(h.code())


## The hull's picture as an image (read from the file: a headless texture has none).
func _picture(fr: HullData, tier: int) -> Image:
	var tex := DB.hull_sprite(fr.weight, tier, false, fr.manufacturer)
	if tex == null:
		return null
	var img := Image.load_from_file(tex.resource_path)
	if img != null and img.is_compressed():
		img.decompress()
	return img
