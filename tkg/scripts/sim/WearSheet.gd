extends RefCounted

## Every damage band of every hull with real art, as PNGs — plus the cost of
## building one, which is the number that decides whether this can run in a fight.
##
##     godot --headless --path . -- wear
##
## Needs no renderer: HullWear works on an Image and an Image is a file. It also
## PROVES the thing that matters, which is not that the grades render but that
## they render CLEAN — the whole argument for drawing wear rather than generating
## it is that arithmetic cannot introduce a colour, and this counts them.

const OUT := "user://wear"
## What fraction of the hull is gone at each band, for the labels. band_for()
## owns the real thresholds; these are the middle of each range.
const AT := [0.0, 0.35, 0.60, 0.90]

## Which run to render. `-- wear seed=N` renders that run's scars; without it,
## run 1, so the sheet is reproducible and two invocations can be compared.
var _run: int = 1
var _pilot: String = ""

func run(tree: SceneTree) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			_run = int(a.substr(5))
		elif a.begins_with("pilot="):
			_pilot = a.substr(6)
	DirAccess.make_dir_recursive_absolute(OUT)
	print("run seed %d, pilot %s" % [_run, "\"%s\"" % _pilot if _pilot else "(none)"])
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
	var base := HullWear.palette(src)
	print("\n%s (%s)" % [h.name.to_upper(), HullData.weight_name(h.weight)])
	print("  %-8s %-8s %-13s %-10s %-9s %s"
		% ["band", "opaque", "new colours", "hull lost", "livery", "build"])
	for t in 4:
		var t0 := Time.get_ticks_usec()
		var img := HullWear.worn(src, t, HullWear.seed_for(h, _pilot, _run))
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		var pal := HullWear.palette(img)
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
					# that scrubs the manufacturer colour off is a grade that costs the
					# player the ability to tell whose ship they are looking at.
					if c.r - c.b > 0.157 and c.r > 0.392:
						livery += 1
				elif was.a > 0.0:
					lost += 1
		var fresh := 0
		for k in pal:
			if not base.has(k):
				fresh += 1
		print("  %-8s %-8d %-13d %-10d %-9s %.1f ms"
			% [_grade_name(t), opaque, fresh, lost,
			"%.1f%%" % (100.0 * livery / maxi(1, opaque)), ms])
		img.save_png("%s/%s_%s.png" % [OUT, h.name.to_lower().replace(" ", "_"),
			_grade_name(t)])
	return 1

## Bands are named for the damage that earns them, NOT for a tier letter. The
## letters belong to the specification ladder and mean something else entirely.
func _grade_name(t: int) -> String:
	return ["intact", "marked", "mauled", "wrecked"][clampi(t, 0, 3)]

