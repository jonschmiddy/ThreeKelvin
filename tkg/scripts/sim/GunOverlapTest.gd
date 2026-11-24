extends Node

## Which guns can overlap on a hull, as a report (Jon, Nov 17: "Overlap is fine"): every hull whose mounts say their side (`HullData.gun_sides`),
## at the grade with the most weapon mounts, every pair of its weapon mounts, every pair of weapons
## (any gun goes on any mount, Jon's ruling B), drawn boxes as `MountPoints.part_rect` gives them at 1x.
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
	var seen := {}
	var per := {}   # hull key -> "i×j" -> overlapping gun pairs, so the report says which mounts clash
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
					for b in guns:
						pairs += 1
						var ra := _box(mp, a, i, pts[i])
						var rb := _box(mp, b, j, pts[j])
						if ra.intersects(rb):
							var pk := "%s mounts %d and %d" % [key, i + 1, j + 1]
							per[pk] = int(per.get(pk, 0)) + 1
		mp.free()
	print("  %d hulls, %d weapons, %d pairs of guns on pairs of mounts" % [hulls, guns.size(), pairs])
	for pk: String in per:
		print("  clash: %s (%d of %d gun pairs)" % [pk, per[pk], guns.size() * guns.size()])
	# Every gun with an on-ship picture has one for both sides: one side only would stand
	# on the other side's mounts as its hold icon (the KH-500 and Widowmanufacturer on top, Nov 17).
	var one_sided: Array[String] = []
	for id: StringName in ShipGun.ids():
		if ShipGun.of(id, &"top") == null or ShipGun.of(id, &"belly") == null:
			one_sided.append(String(id))
	h._ok("every on-ship gun has a top and a belly picture (missing: %s)" % ", ".join(one_sided),
		one_sided.is_empty() and not ShipGun.ids().is_empty())
	h._ok("there is a hull with on-ship guns to check", hulls > 0 and pairs > 0)
	_manufacturers()
	# (overlap is allowed, Jon Nov 17: the clashes above are a report, not a failure)
	h.verdict("gunoverlaptest")
	get_tree().quit(h.code())


## The box `m` is drawn in on mount `i` (a copy, so the catalogue's part is never moved).
func _box(mp: MountPoints, m: ModuleData, i: int, at: Vector2) -> Rect2:
	var c := m.duplicate() as ModuleData
	c.mount = i
	return mp.part_rect(c, ModuleData.Slot.WEAPON, at, 1.0)


## The yard guns drawn in each manufacturer's colours: both sides, the plain gun's canvas and anchor,
## a different picture, and only unbranded guns on that manufacturer's hull. Why: docs/why/ShipGun.md#manufacturer-drawn-yard-guns
func _manufacturers() -> void:
	var bad: Array[String] = []
	for manufacturer: StringName in [&"korvan", &"solari"]:
		for id: StringName in [&"beam", &"slug", &"torch"]:
			for side: StringName in [&"top", &"belly"]:
				var p := ShipGun.of(id, side)
				var g := ShipGun.of(id, side, manufacturer)
				if p == null or g == null or g.tex == p.tex or g.size() != p.size() or g.anchor != p.anchor:
					bad.append("%s %s %s" % [manufacturer, id, side])
	h._ok("Korvan and Solari draw each yard gun on both sides, on the plain canvas and anchor (wrong: %s)"
		% ", ".join(bad), bad.is_empty())
	h._ok("a branded gun ignores the manufacturer", ShipGun.of(&"kh20", &"top", &"solari").tex == ShipGun.of(&"kh20", &"top").tex)
	h._ok("a manufacturer with no copies falls back to the plain gun",
		ShipGun.of(&"beam", &"top", &"probate").tex == ShipGun.of(&"beam", &"top").tex)
	# gun_for: the hull's manufacturer for an unbranded weapon only
	var mp := MountPoints.new()
	for fr: HullData in DB.hull_frames:
		var hull := DB.at_tier(fr, HullData.TIER_NAMES.size() - 1)
		if hull.manufacturer == &"solari" and not hull.gun_sides.is_empty():
			mp.ship = hull
			break
	h._ok("there is a Solari hull with on-ship guns", mp.ship != null)
	if mp.ship != null:
		var side: StringName = mp.ship.gun_sides[0]
		var beam := (DB.modules[&"beam"] as ModuleData).duplicate() as ModuleData
		var kh20 := (DB.modules[&"kh20"] as ModuleData).duplicate() as ModuleData
		beam.mount = 0
		kh20.mount = 0
		var gb := mp.gun_for(beam, ModuleData.Slot.WEAPON)
		var gk := mp.gun_for(kh20, ModuleData.Slot.WEAPON)
		h._ok("on a Solari hull the Mining Laser is Solari's drawing",
			gb != null and gb.tex == ShipGun.of(&"beam", side, &"solari").tex and gb.tex != ShipGun.of(&"beam", side).tex)
		h._ok("on a Solari hull the KH-20 keeps Korvan's own picture", gk != null and gk.tex == ShipGun.of(&"kh20", side).tex)
	mp.free()
