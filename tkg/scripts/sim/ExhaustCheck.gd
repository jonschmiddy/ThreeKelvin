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
	var plumes := 0
	var behind := 0
	for h in DB.hull_frames:
		if not h.has_exhaust():
			print("hull '%s' has no exhaust" % h.name)
			bad += 1
			continue
		var key := DB.hull_art_name(h.weight, h.tier)
		var listed := DB.HULL_EXHAUST.has(key)
		if listed:
			rigged += 1
			# EVERY entry, not just the first. A hull can carry three, and a check
			# that looked only at the first would pass a ship whose other two were
			# hanging off the canvas.
			var want: Array = DB.HULL_EXHAUST[key]
			if h.thrusters.size() != want.size():
				print("hull '%s' (%s) carries %d plumes, rigged for %d" % [h.name, key, h.thrusters.size(), want.size()])
				bad += 1
		elif h.thrusters.size() != 1:
			print("hull '%s' is unrigged, should fall back to one plume, has %d" % [h.name, h.thrusters.size()])
			bad += 1
		var sw := h.sprite.get_width() if h.sprite != null else 0
		var sh := h.sprite.get_height() if h.sprite != null else 0
		for i in h.thrusters.size():
			var t: Dictionary = h.thrusters[i]
			plumes += 1
			if bool(t.get("back", false)):
				behind += 1
			var tex: Texture2D = t.get("tex")
			if tex == null:
				print("hull '%s' plume %d has no texture" % [h.name, i])
				bad += 1
				continue
			var at: Vector2i = t.at
			if not listed:
				var want_at := DB.hull_exhaust_at(h.weight, h.tier, int(t.id))
				if at != want_at:
					print("hull '%s' unrigged plume at %s, expected %s" % [h.name, at, want_at])
					bad += 1
			# A plume hanging off the canvas is cut off by ShipView._paste(), which is
			# silent. The rigging bench warns about it; so does this.
			var fw := tex.get_width() / DB.EXHAUST_FRAMES
			var over := at.x < 0 or at.y < 0
			over = over or (sw > 0 and at.x + fw > sw)
			over = over or (sh > 0 and at.y + tex.get_height() > sh)
			if over:
				print("hull '%s' plume %d (%dx%d) at %s overhangs its %dx%d canvas" % [h.name, i, fw, tex.get_height(), at, sw, sh])
				bad += 1
	print("%d of %d hull frames rigged by hand, %d plumes (%d behind the hull)" % [rigged, DB.hull_frames.size(), plumes, behind])

	print("\n%s" % ("OK" if bad == 0 else "%d PROBLEM(S)" % bad))
	tree.quit(0 if bad == 0 else 1)
