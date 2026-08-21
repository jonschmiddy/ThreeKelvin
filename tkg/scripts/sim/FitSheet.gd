extends RefCounted

## Every CLASS of every hull with real art, as PNGs.
##
##     godot --headless --path . -- fit
##
## Companion to `-- wear`. That one takes a hull apart; this one kits it out,
## and the two compose — a C-class flying wrecked and an S-class flying intact
## are the two ends of what a Korvan medium can look like.

const OUT := "user://fit"
var _seed: int = 1
var _band: int = 0

func run(tree: SceneTree) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			_seed = int(a.substr(5))
		elif a.begins_with("damage="):
			_band = clampi(int(a.substr(7)), 0, 3)
	DirAccess.make_dir_recursive_absolute(OUT)
	print("seed %d, damage band %d" % [_seed, _band])
	# The LIGHT frames now, not the first frame with art. Light is the only
	# weight with a real class ladder, and rendering a medium four times to show
	# the same sprite four times proves nothing.
	for h in DB.hull_frames:
		if h.sprite == null or h.weight != HullData.Weight.LIGHT:
			continue
		_sheet(h)
		break
	print("\nwrote to %s" % ProjectSettings.globalize_path(OUT))
	tree.quit()

func _sheet(h: HullData) -> void:
	var src := h.sprite.get_image()
	var base := _palette(src)
	print("\n%s" % h.name.to_upper())
	print("  %-6s %-8s %-13s %s" % ["class", "opaque", "new colours", "build"])
	for c in 4:
		var t0 := Time.get_ticks_usec()
		# The class's OWN sprite, not the C-class one with fittings composited on.
		var frame := DB.at_tier(h, c)
		var img := (frame.sprite.get_image() if frame.sprite != null
			else src) as Image
		# Fittings go on BEFORE damage, so a bolt-on can be shot off.
		if _band > 0:
			img = HullWear.worn(img, _band, _seed)
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
		print("  %-6s %-8d %-13d %.1f ms"
			% [HullData.TIER_NAMES[c], opaque, fresh, ms])
		img.save_png("%s/%s_%s.png" % [OUT, h.name.to_lower().replace(" ", "_"),
			HullData.TIER_NAMES[c]])

func _palette(img: Image) -> Dictionary:
	var d := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				d[(int(c.r * 255.0) << 16) | (int(c.g * 255.0) << 8) | int(c.b * 255.0)] = 1
	return d
