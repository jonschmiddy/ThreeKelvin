extends Node

## No two guns on a hull ever overlap: every hull whose mounts say their side (`HullData.gun_sides`),
## at the grade with the most weapon mounts, every pair of its weapon mounts, every pair of weapons
## each mount takes (`HullData.mount_fits`), drawn boxes as `MountPoints.part_rect` gives them at 1x.
## `-- sheet=GunOverlapTest` (headless). Why: docs/why/Database.md#on-ship-guns

var h := Harness.new()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	var guns: Array[ModuleData] = []
	for id: StringName in DB.modules:
		var m := DB.modules[id] as ModuleData
		if m.slot == ModuleData.Slot.WEAPON:
			guns.append(m)
	var hulls := 0
	var pairs := 0
	var bad: Array[String] = []
	var seen := {}
	for fr: HullData in DB.hull_frames:
		var hull := DB.at_tier(fr, HullData.TIER_NAMES.size() - 1)
		var key := DB.hull_art_key(hull.weight, hull.tier, hull.manufacturer)
		if hull.gun_sides.is_empty() or seen.has(key):
			continue
		seen[key] = true
		hulls += 1
		var mp := MountPoints.new()
		mp.ship = hull
		var pts := hull.mounts_along(ModuleData.Slot.WEAPON, hull.slots_for(ModuleData.Slot.WEAPON))
		for i in pts.size():
			for j in range(i + 1, pts.size()):
				for a in guns:
					if not hull.mount_fits(a, i):
						continue
					for b in guns:
						if not hull.mount_fits(b, j):
							continue
						pairs += 1
						var ra := _box(mp, a, i, pts[i])
						var rb := _box(mp, b, j, pts[j])
						if ra.intersects(rb) and bad.size() < 20:
							bad.append("%s: %s on %d %s and %s on %d %s" % [key, a.id, i, ra, b.id, j, rb])
		mp.free()
	print("  %d hulls, %d weapons, %d pairs of guns on pairs of mounts" % [hulls, guns.size(), pairs])
	for b in bad:
		print("  overlap: %s" % b)
	h._ok("there is a hull with on-ship guns to check", hulls > 0 and pairs > 0)
	h._ok("no two guns overlap on any hull (%d listed)" % bad.size(), bad.is_empty())
	h.verdict("gunoverlaptest")
	get_tree().quit(h.code())


## The box `m` is drawn in on mount `i` (a copy, so the catalogue's part is never moved).
func _box(mp: MountPoints, m: ModuleData, i: int, at: Vector2) -> Rect2:
	var c := m.duplicate() as ModuleData
	c.mount = i
	return mp.part_rect(c, ModuleData.Slot.WEAPON, at, 1.0)
