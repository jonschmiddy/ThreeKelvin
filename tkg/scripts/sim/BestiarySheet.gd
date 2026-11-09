extends RefCounted

## Composites on the CPU, so it needs no renderer. Its point is the substance split in damage bands.
## Why: docs/why/BestiarySheet.md#bestiary-sheet

const OUT := "user://bestiary"
const BANDS := ["intact", "marked", "mauled", "wrecked"]

## `art` value -> what the thing is made of. Anything not named here is fauna,
## which matches EnemyArt's own `match` falling through to _draw_fauna.
const STUFF := {
	&"cutter": HullWear.Substance.METAL,
	&"hulk": HullWear.Substance.METAL,
	&"hellbender": HullWear.Substance.METAL,
}

var _seed: int = 1

func run(tree: SceneTree) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			_seed = int(a.substr(5))
	DirAccess.make_dir_recursive_absolute(OUT)
	for art in [&"cutter", &"hulk", &"hellbender", &"leviathan"]:
		_sheet(art)
	print("\nwrote to %s" % ProjectSettings.globalize_path(OUT))
	tree.quit()

func _sheet(art: StringName) -> void:
	var sub: int = STUFF.get(art, HullWear.Substance.ORGANIC)
	var kind := "metal" if sub == HullWear.Substance.METAL else "organic"
	print("\n%s (%s)" % [String(art).to_upper(), kind])
	print("  %-8s %-8s %-13s %s" % ["band", "opaque", "new colours", "build"])

	# Not added to the tree: it needs a parent only to be seen, and `add_child` in `_ready` fails.
	var view := EnemyArt.new()
	var e := Combat.EnemyState.new()
	e.template = EnemyTemplate.new()
	e.template.art = art
	e.template.name = String(art)
	e.max_hp = 80
	e.hp = 80
	view.set_enemy(e, false)
	var src: Image = (view._img as Image).duplicate() as Image
	var base := HullWear.palette(src)

	for t in 4:
		var t0 := Time.get_ticks_usec()
		var img := HullWear.worn(src, t, _seed, false, sub)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		var pal := HullWear.palette(img)
		var fresh := 0
		for k in pal:
			if not base.has(k):
				fresh += 1
		var opaque := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.0:
					opaque += 1
		print("  %-8s %-8d %-13d %.1f ms" % [BANDS[t], opaque, fresh, ms])
		img.save_png("%s/%s_%s.png" % [OUT, art, BANDS[t]])
	view.queue_free()

