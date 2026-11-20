extends Node

## Every HullScars idea on the same hulls, C to S, lit at rest, for a side-by-side pick sheet.
## Why: docs/why/HullScars.md#hull-scars

const HULLS := ["korvan/hull_light_zero", "korvan/hull_medium_zero", "korvan/hull_heavy_zero",
	"solari/hull_light_zero", "solari/hull_medium_zero", "solari/hull_heavy_zero"]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := Harness.arg("out", "user://gradedrama")
	DirAccess.make_dir_recursive_absolute(out)
	var fails := 0
	for idea in HullScars.Idea.values():
		HullGrade.drama = idea
		for key: String in HULLS:
			var src: Image = (load("res://art/sprites/hulls/%s.png" % key) as Texture2D).get_image()
			src.convert(Image.FORMAT_RGBA8)
			var pal := HullWear.palette(src)
			for c: Color in HullGrade.band_ramp(key):
				pal[HullGrade.key(c)] = true
			for g in 4:
				var img := HullGrade.bake_mix(src, g, HullGrade.SHIPPED, 7, key)
				var extra := 0
				for k in HullWear.palette(img):
					if not pal.has(k):
						extra += 1
				if extra > 0:
					fails += 1
				print("  idea %d %s %s: %d off-palette" % [idea, key, "CBAS"[g], extra])
				HullGrade.lit(img, g, key).save_png("%s/i%d_%s_%d.png" % [out, idea, key.replace("/", "_"), g])
	HullGrade.drama = HullGrade.DRAMA
	print("gradedrama: %s" % ("PASS" if fails == 0 else "%d off-palette" % fails))
	get_tree().quit(0 if fails == 0 else 1)
