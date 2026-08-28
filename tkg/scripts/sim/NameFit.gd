extends Harness

## How tall the destination title can get:
##   godot --headless --path . -- namefit
##
## The right-hand panel's height is driven by its tallest content, and the chart
## shares a row with it -- so a name that wraps to a second line moves the whole
## screen. Reported as "clicking Theta Abyssal Secundus completely changes how
## the panel and star chart are rendered size-wise".
##
## The fix is to RESERVE the height, and that needs a number rather than a guess:
## reserve one line too few and the jump comes back on a longer name, one too
## many and the panel carries a permanent gap. So this measures every name a real
## galaxy generates, at the real font and the real width.

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
