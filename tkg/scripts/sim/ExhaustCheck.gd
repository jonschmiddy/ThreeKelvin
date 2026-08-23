extends RefCounted

## Every exhaust strip in the library, loaded and measured.
##
##   godot --headless --path . -- exhaust
##
## WHY THIS EXISTS. A plume that fails to load is invisible rather than loud:
## `exhaust` goes null, `ShipView` skips the blit, and the ship simply flies with
## its engines out. Nothing throws and no test fails. The same is true of a strip
## whose width is not a multiple of `EXHAUST_FRAMES` — the slicer takes a
## truncated cell and the flame develops a seam that only shows in motion.
##
## So this asserts the two things the art has to be true about, per file, and
## prints the frame size and offset so a wrong-looking plume can be checked
## against a number instead of an impression.


func run(tree: SceneTree) -> void:
	# One frame before anything, for the reason ConvoyTest records: Main is still
	# inside _ready(), and quitting the tree from inside a node's setup hangs
	# rather than exits.
	await tree.process_frame
	var bad := 0
	print("exhaust library: %d strips, %d frames each"
		% [DB.EXHAUST_COUNT, DB.EXHAUST_FRAMES])
	print("%-11s %-10s %-9s %-8s %s" % ["id", "strip", "frame", "offset", ""])
	for id in DB.EXHAUST_COUNT:
		var tex := DB.exhaust_art(id)
		if tex == null:
			print("exhaust_%-3d FAILED TO LOAD" % id)
			bad += 1
			continue
		var w := tex.get_width()
		var h := tex.get_height()
		var note := ""
		if w % DB.EXHAUST_FRAMES != 0:
			note = "WIDTH NOT DIVISIBLE BY %d" % DB.EXHAUST_FRAMES
			bad += 1
		var at := DB.hull_exhaust_at(HullData.Weight.HEAVY, 0, id)
		print("exhaust_%-3d %-10s %-9s %-8s %s"
			% [id, "%dx%d" % [w, h], "%dx%d" % [w / DB.EXHAUST_FRAMES, h],
			   "%d,%d" % [at.x, at.y], note])

	# And the wiring. Two ways a hull can get its offset and both must hold:
	# one RIGGED in the bench carries the offset a person placed, one that has
	# not been rigged falls back to centring on its own canvas. Checking only
	# the second is how this file first reported a correctly-rigged hull as
	# broken.
	print("")
	var rigged := 0
	for h in DB.hull_frames:
		if h.exhaust == null:
			print("hull '%s' has no exhaust" % h.name)
			bad += 1
			continue
		var key := DB.hull_art_name(h.weight, h.tier)
		var want: Vector2i
		if DB.HULL_EXHAUST.has(key):
			want = (DB.HULL_EXHAUST[key] as Dictionary).at
			rigged += 1
		else:
			want = DB.hull_exhaust_at(h.weight, h.tier, h.exhaust_id)
		if h.exhaust_offset != want:
			print("hull '%s' (%s) offset %s, expected %s"
				% [h.name, key, h.exhaust_offset, want])
			bad += 1
		# A plume hanging off the canvas is cut off by ShipView._paste(), which
		# is silent. The rigging bench warns about it; so does this.
		var tex := h.exhaust
		if tex != null:
			var fw := tex.get_width() / DB.EXHAUST_FRAMES
			var sw := h.sprite.get_width() if h.sprite != null else 0
			var sh := h.sprite.get_height() if h.sprite != null else 0
			if h.exhaust_offset.x < 0 or h.exhaust_offset.y < 0 \
					or (sw > 0 and h.exhaust_offset.x + fw > sw) \
					or (sh > 0 and h.exhaust_offset.y + tex.get_height() > sh):
				print("hull '%s' plume %dx%d at %s overhangs its %dx%d canvas"
					% [h.name, fw, tex.get_height(), h.exhaust_offset, sw, sh])
				bad += 1
	print("%d of %d hull frames rigged by hand" % [rigged, DB.hull_frames.size()])

	print("\n%s" % ("OK" if bad == 0 else "%d PROBLEM(S)" % bad))
	tree.quit(0 if bad == 0 else 1)
