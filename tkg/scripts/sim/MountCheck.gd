extends Harness

## Every hull's mounts against its own pixels:
##   godot --headless --path . -- mounts
##
## The dorsal, ventral and flank lines are measured off ONE specific image each
## by `art/tools/anchors.py`. So the failure this exists for is a hull sprite
## replaced without the tool being re-run: the new art has a different
## silhouette, the old line still describes the old one, and the ship draws its
## guns in clear space beside itself. Nothing throws, nothing logs, and the only
## way to notice is to look at that exact hull at that exact class.
##
## It has already caught it once, on the swap of Korvan's heavy B.


func run() -> void:
	var images := {}
	var total := 0
	var off := 0
	print("\n%-8s %-6s %-10s %-14s %s"
		% ["hull", "class", "canvas", "mounts w/s/u", "off-hull"])
	for w in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
		for t in HullData.TIER_NAMES.size():
			var h := DB.at_tier(DB.hull_for(&"korvan", w) as HullData, t)
			var tex := h.sprite
			if not _ok("%s %s has art" % [HullData.weight_name(w),
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
			print("  %-8s %-6s %-10s %-14s %s" % [
				HullData.weight_name(w), HullData.TIER_NAMES[t],
				"%dx%d" % [tex.get_width(), tex.get_height()],
				"%d / %d / %d" % [counts[0], counts[1], counts[2]],
				str(stray) if stray > 0 else "-"])
	_ok("%d mounts all land on hull" % total, off == 0)
	verdict("mounts")


## Is there hull within a few pixels of this point?
##
## A radius rather than the exact pixel, because the dorsal line sits ON the top
## edge: a mount is meant to be at the boundary, so demanding an opaque pixel
## under it would fail every correctly placed one.
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
