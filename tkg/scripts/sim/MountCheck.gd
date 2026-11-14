extends Harness

## Catches a hull sprite replaced without re-running `anchors.py`, which fails silently.
## Why: docs/why/MountCheck.md#mount-check


func run() -> void:
	var images := {}
	var total := 0
	var off := 0
	print("
%-8s %-8s %-6s %-10s %-14s %s"
		% ["folder", "hull", "class", "canvas", "mounts w/s/u", "off-hull"])
	# EVERY MANUFACTURER WITH PICTURES OF ITS OWN (`DB.HULL_ART`). The other five
	# fly Korvan's pictures on Korvan's mounts, so Korvan's rows cover them.
	for mf: StringName in DB.HULL_ART:
		for w in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
			for t in HullData.TIER_NAMES.size():
				var h := DB.at_tier(DB.hull_for(mf, w) as HullData, t)
				var tex := h.sprite
				if not _ok("%s %s %s has art" % [mf, HullData.weight_name(w),
						HullData.TIER_NAMES[t]], tex != null):
					continue
				if not images.has(tex.resource_path):
					images[tex.resource_path] = tex.get_image()
				var img: Image = images[tex.resource_path]
				var counts := PackedInt32Array()
				var stray := 0
				for s in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM,
						ModuleData.Slot.UTILITY]:
					var n := h.slots_for(s)
					counts.append(n)
					for p in h.mounts_along(s, n):
						total += 1
						if not _on_hull(img, p):
							stray += 1
				off += stray
				print("  %-8s %-8s %-6s %-10s %-14s %s" % [
					mf, HullData.weight_name(w), HullData.TIER_NAMES[t],
					"%dx%d" % [tex.get_width(), tex.get_height()],
					"%d / %d / %d" % [counts[0], counts[1], counts[2]],
					str(stray) if stray > 0 else "-"])
	_ok("%d mounts all land on hull" % total, total > 0 and off == 0)
	verdict("mounts")


## A radius, not the exact pixel: the dorsal line sits on the top edge.
func _on_hull(img: Image, p: Vector2) -> bool:
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var x := int(p.x) + dx
			var y := int(p.y) + dy
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			if img.get_pixel(x, y).a > 0.0:
				return true
	return false
