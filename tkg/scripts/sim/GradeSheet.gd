extends Node

## ONE HULL, FOUR GRADES, in each of HullGrade's looks, as PNGs for a pick page:
##   godot --headless --path . -- sheet=GradeSheet out=<dir> [weight=medium] [base=a] [manufacturer=korvan]
##
## `base` is which of today's four sprites is the one hull (c, b, a, s). Writes
## `<look>_<grade>.png` (A_c ... C_s, and the mixes AB, AC, BC, ABC) at the sprite's own size, today's four as
## `today_<grade>.png`, and prints each bake's colour count against the base's:
## a bake may only use colours the base already has.

func _arg(k: String, d: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.get_slice("=", 1)
	return d


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := _arg("out", "user://gradesheet")
	DirAccess.make_dir_recursive_absolute(out)
	var wt := _arg("weight", "medium")
	var base := _arg("base", "a")
	var mk := _arg("manufacturer", "korvan")
	# `reglook=A|B|C`: the registry's look on trial (`HullGrade.reg_look`)
	HullGrade.reg_look = StringName(_arg("reglook", "A"))
	var grades := ["c", "b", "a", "s"]
	if mk == "korvan":
		for g in grades:
			var t: Texture2D = load("res://art/sprites/hulls/korvan/hull_%s_%s.png" % [wt, g])
			t.get_image().save_png("%s/today_%s.png" % [out, g])
	var src: Image = (load("res://art/sprites/hulls/%s/hull_%s_%s.png" % [mk, wt, base]) as Texture2D).get_image()
	src.convert(Image.FORMAT_RGBA8)
	var pal := HullWear.palette(src)
	# the manufacturer's band ramp is allowed too: HullGrade._band puts every
	# hull's band onto it
	for c: Color in HullGrade.band_ramp("%s/hull_%s_%s" % [mk, wt, base]):
		pal[HullGrade.key(c)] = true
	var fails := 0
	for lk in HullGrade.LOOKS:
		for gi in 4:
			var img := HullGrade.bake(src, gi, HullGrade.LOOKS[lk], 7, "%s/hull_%s_%s" % [mk, wt, base])
			if lk == &"E":
				HullGrade.lit(img, gi, "%s/hull_%s_%s" % [mk, wt, base]).save_png("%s/%s_%s.png" % [out, lk, grades[gi]])
			else:
				img.save_png("%s/%s_%s.png" % [out, lk, grades[gi]])
			var extra := 0
			for k in HullWear.palette(img):
				if not pal.has(k):
					extra += 1
			if extra > 0:
				fails += 1
			print("  %s %s: %d colours not in the base" % [lk, grades[gi], extra])
	# and every combination of two or three
	for combo in ["AB", "ABD", "ABE", "ABF", "ABDEF"]:
		var looks: Array = []
		for ch in combo:
			looks.append(HullGrade.LOOKS[StringName(ch)])
		for gi in 4:
			var img := HullGrade.bake_mix(src, gi, looks, 7, "%s/hull_%s_%s" % [mk, wt, base])
			# with E, the still is the hull and its light layer as the game draws them
			if "E" in combo:
				HullGrade.lit(img, gi, "%s/hull_%s_%s" % [mk, wt, base]).save_png("%s/%s_%s.png" % [out, combo, grades[gi]])
			else:
				img.save_png("%s/%s_%s.png" % [out, combo, grades[gi]])
			var extra := 0
			for k in HullWear.palette(img):
				if not pal.has(k):
					extra += 1
			if extra > 0:
				fails += 1
			print("  %s %s: %d colours not in the base" % [combo, grades[gi], extra])
	# `film=<dir>`: AB+E at A and S, the lights live, 90 frames at 30 a second
	var film := _arg("film", "")
	if film != "":
		for gi in [2, 3]:
			var lk: Array = [HullGrade.LOOKS[&"A"], HullGrade.LOOKS[&"B"], HullGrade.LOOKS[&"E"]]
			var bk := HullGrade.bake_mix(src, gi, lk, 7, "%s/hull_%s_%s" % [mk, wt, base])
			DirAccess.make_dir_recursive_absolute("%s/%s" % [film, grades[gi]])
			for f in 90:
				HullGrade.lit(bk, gi, "%s/hull_%s_%s" % [mk, wt, base], float(f) / 30.0).save_png(
					"%s/%s/f%03d.png" % [film, grades[gi], f])
	print("gradesheet: %s" % ("PASS" if fails == 0 else "%d off-palette" % fails))
	get_tree().quit(0 if fails == 0 else 1)
