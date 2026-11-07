extends Harness

## Reserving the height needs a number: this measures every generated name at real font and width.
## Why: docs/why/NameFit.md#name-fit

## `_dest_name.custom_minimum_size.x`, which is what it wraps against.
const PANEL_W := 228.0


func run() -> void:
	var font := UITheme.pixel_font()
	var size := UITheme.FS_HEAD
	var lh := font.get_height(size)
	var worst := 0
	var worst_name := ""
	var counts: Dictionary = {}
	var seen: Dictionary = {}
	for seed_i in [11, 4242, 90210, 31337, 777]:
		Rng.forced = seed_i
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		for node in Run.map:
			var nm := MapGen.star_name(node as MapGen.MapNode)
			if seen.has(nm):
				continue
			seen[nm] = true
			# `get_multiline_string_size` wraps the way an autowrapped Label does.
			var h := font.get_multiline_string_size(
				nm, HORIZONTAL_ALIGNMENT_LEFT, PANEL_W, size).y
			var lines := int(round(h / float(lh)))
			counts[lines] = int(counts.get(lines, 0)) + 1
			if lines > worst:
				worst = lines
				worst_name = nm
	print("\n  %d distinct names over 5 galaxies" % seen.size())
	print("  line height %d at FS_HEAD %d, wrapping at %dpx"
		% [lh, size, int(PANEL_W)])
	for k in [1, 2, 3, 4]:
		if counts.has(k):
			print("    %d line%s: %d names (%.1f%%)"
				% [k, "" if k == 1 else "s", int(counts[k]),
					100.0 * float(counts[k]) / float(seen.size())])
	print("  worst: %s at %d lines" % [worst_name, worst])
	_ok("no name needs more than two lines (worst: %s)" % worst_name, worst <= 2)
	verdict("namefit")
