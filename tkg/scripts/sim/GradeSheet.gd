extends Node

## ONE HULL, FOUR GRADES, in each of HullGrade's looks, as PNGs for a pick page:
##   godot --headless --path . -- sheet=GradeSheet out=<dir> [weight=medium] [base=a]
##
## `base` is which of today's four sprites is the one hull (c, b, a, s). Writes
## `<look>_<grade>.png` (A_c ... C_s) at the sprite's own size, today's four as
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
	var grades := ["c", "b", "a", "s"]
	for g in grades:
		var t: Texture2D = load("res://art/sprites/hulls/korvan/hull_%s_%s.png" % [wt, g])
		t.get_image().save_png("%s/today_%s.png" % [out, g])
	var src: Image = (load("res://art/sprites/hulls/korvan/hull_%s_%s.png" % [wt, base]) as Texture2D).get_image()
	src.convert(Image.FORMAT_RGBA8)
	var pal := HullWear.palette(src)
	var fails := 0
	for lk in HullGrade.LOOKS:
		for gi in 4:
			var img := HullGrade.bake(src, gi, HullGrade.LOOKS[lk])
			img.save_png("%s/%s_%s.png" % [out, lk, grades[gi]])
			var extra := 0
			for k in HullWear.palette(img):
				if not pal.has(k):
					extra += 1
			if extra > 0:
				fails += 1
			print("  %s %s: %d colours not in the base" % [lk, grades[gi], extra])
	print("gradesheet: %s" % ("PASS" if fails == 0 else "%d off-palette" % fails))
	get_tree().quit(0 if fails == 0 else 1)
