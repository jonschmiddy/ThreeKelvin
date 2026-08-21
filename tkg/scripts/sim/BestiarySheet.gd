extends RefCounted

## Every enemy body at every damage band, as PNGs.
##
##     godot --headless --path . -- bestiary
##
## EnemyArt is a TextureRect but it composites CPU-side into an Image, so it
## works with no renderer at all — the same trick WearSheet uses on hulls.
##
## The point of this one is the SUBSTANCE split. A whale does not weld and a
## gunship does not scar, and this is where that gets looked at rather than
## argued about.

const OUT := "user://bestiary"
const BANDS := ["intact", "marked", "mauled", "wrecked"]

## `art` value -> what the thing is made of. Anything not named here is fauna,
## which matches EnemyArt's own `match` falling through to _draw_fauna.
const STUFF := {
	&"cutter": HullWear.Substance.METAL,
	&"hulk": HullWear.Substance.METAL,
}

var _seed: int = 1

func run(tree: SceneTree) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			_seed = int(a.substr(5))
	DirAccess.make_dir_recursive_absolute(OUT)
	for art in [&"cutter", &"hulk", &"leviathan"]:
		_sheet(art)
	print("\nwrote to %s" % ProjectSettings.globalize_path(OUT))
	tree.quit()

func _sheet(art: StringName) -> void:
	var sub: int = STUFF.get(art, HullWear.Substance.ORGANIC)
	var kind := "metal" if sub == HullWear.Substance.METAL else "organic"
	print("\n%s (%s)" % [String(art).to_upper(), kind])
	print("  %-8s %-8s %-13s %s" % ["band", "opaque", "new colours", "build"])

	# NOT added to the tree. EnemyArt composites into its own Image inside
	# set_enemy() and only needs a parent to be SEEN, which is exactly what this
	# does not want — and add_child() during _ready() fails anyway.
	var view := EnemyArt.new()
	var e := Combat.EnemyState.new()
	e.template = EnemyTemplate.new()
	e.template.art = art
	e.template.name = String(art)
	e.max_hp = 80
	e.hp = 80
	view.set_enemy(e, false)
	var src: Image = (view._img as Image).duplicate() as Image
	var base := _palette(src)

	for t in 4:
		var t0 := Time.get_ticks_usec()
		var img := HullWear.worn(src, t, _seed, false, sub)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		var pal := _palette(img)
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

func _palette(img: Image) -> Dictionary:
	var d := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				d[(int(c.r * 255.0) << 16) | (int(c.g * 255.0) << 8) | int(c.b * 255.0)] = 1
	return d
