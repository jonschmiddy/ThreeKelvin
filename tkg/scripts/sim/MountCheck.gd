extends RefCounted
## Every hull's mounts, at every class, as numbers you can check against the art.
##
## The lines are measured against ONE sprite each, so the failure this catches is
## a hull carrying another hull's lines — which draws guns in mid-air and throws
## nothing. Compares each mount against the sprite's own opaque pixels.
class_name MountCheck

static func run() -> void:
	var img_cache := {}
	var bad := 0
	var total := 0
	print("\n%-16s %-6s %-9s %-26s %s" % ["hull", "class", "canvas", "mounts w/s/u", "off-hull"])
	for w in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
		for t in 4:
			var frame := DB.hull_for(&"korvan", w) as HullData
			var h := DB.at_tier(frame, t)
			var tex := h.sprite
			if tex == null:
				print("  %-16s no sprite" % HullData.weight_name(w))
				continue
			var key := tex.resource_path
			if not img_cache.has(key):
				img_cache[key] = tex.get_image()
			var img: Image = img_cache[key]
			var counts := PackedInt32Array()
			var off := 0
			for s in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM,
					ModuleData.Slot.UTILITY]:
				var n := h.slots_for(s)
				counts.append(n)
				for p in h.mounts_along(s, n):
					total += 1
					# Within a few pixels of real hull? The dorsal line sits ON
					# the top edge, so a small radius is the honest test.
					var hit := false
					for dy in range(-3, 4):
						for dx in range(-3, 4):
							var x := int(p.x) + dx
							var y := int(p.y) + dy
							if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
								continue
							if img.get_pixel(x, y).a > 0.0:
								hit = true
								break
						if hit:
							break
					if not hit:
						off += 1
						bad += 1
			print("  %-16s %-6s %-9s %-26s %s" % [
				HullData.weight_name(w), HullData.TIER_NAMES[t],
				"%dx%d" % [tex.get_width(), tex.get_height()],
				"%d / %d / %d" % [counts[0], counts[1], counts[2]],
				"%d" % off if off > 0 else "-"])
	print("\n%d mounts checked, %d off the hull" % [total, bad])
	print("VERDICT: %s" % ("PASS" if bad == 0 else "FAIL"))
