extends RefCounted

## Every condition grade of every hull with real art, as PNGs.
##
##     godot --headless --path . -- wear
##
## Needs no renderer: HullWear works on an Image and an Image is a file. It also
## PROVES the thing that matters, which is not that the grades render but that
## they render CLEAN — the whole argument for drawing wear rather than generating
## it is that arithmetic cannot introduce a colour, and this counts them.

const OUT := "user://wear"
const NAMES := ["S", "B", "A", "C"]

func run(tree: SceneTree) -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var made := 0
	for h in DB.hull_frames:
		if h.sprite == null:
			continue
		made += _sheet(h)
	if made == 0:
		print("no hull carries real art yet — nothing to wear")
	print("\nwrote %d sheets to %s" % [made, ProjectSettings.globalize_path(OUT)])
	tree.quit()

func _sheet(h: HullData) -> int:
	var src := h.sprite.get_image()
	var base := _palette(src)
	print("\n%s (%s)" % [h.name.to_upper(), HullData.weight_name(h.weight)])
	print("  %-6s %-8s %-13s %-10s %s"
		% ["grade", "opaque", "new colours", "hull lost", "livery"])
	for t in HullWear.GRADES.size():
		var img := HullWear.worn(src, t, HullWear.seed_for(h))
		var pal := _palette(img)
		var opaque := 0
		var lost := 0
		var livery := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				var was := src.get_pixel(x, y)
				if c.a > 0.0:
					opaque += 1
					# The manufacturer's paint. Korvan flies amber, and a grade
					# that scrubs the house colour off is a grade that costs the
					# player the ability to tell whose ship they are looking at.
					if c.r - c.b > 0.157 and c.r > 0.392:
						livery += 1
				elif was.a > 0.0:
					lost += 1
		var fresh := 0
		for k in pal:
			if not base.has(k):
				fresh += 1
		print("  %-6s %-8d %-13d %-10d %.1f%%"
			% [_grade_name(t), opaque, fresh, lost, 100.0 * livery / maxi(1, opaque)])
		img.save_png("%s/%s_%s.png" % [OUT, h.name.to_lower().replace(" ", "_"),
			_grade_name(t)])
	return 1

## HullData.TIER_NAMES runs worst-first (C is 0), which is right for a loot
## ladder and wrong for reading a wear table, where 0 is the pristine end.
func _grade_name(t: int) -> String:
	return ["S", "A", "B", "C"][clampi(t, 0, 3)]

func _palette(img: Image) -> Dictionary:
	var d := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				d[(int(c.r * 255.0) << 16) | (int(c.g * 255.0) << 8) | int(c.b * 255.0)] = 1
	return d
