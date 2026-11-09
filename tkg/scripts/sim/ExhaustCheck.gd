extends RefCounted

## A plume that fails to load is invisible: nothing throws and the ship flies engines out.
## Why: docs/why/ExhaustCheck.md#exhaust-check


func run(tree: SceneTree) -> void:
	# One frame first: quitting the tree from inside a node's setup hangs (see ConvoyTest).
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

	# Both offset paths must hold: rigged in the bench, or centred on the canvas.
	print("")
	var rigged := 0
	var plumes := 0
	var behind := 0
	for h in DB.hull_frames:
		if not h.has_exhaust():
			print("hull '%s' has no exhaust" % h.name)
			bad += 1
			continue
		var key := DB.hull_art_key(h.weight, h.tier, h.manufacturer)
		var listed := DB.HULL_EXHAUST.has(key)
		if listed:
			rigged += 1
			# Every entry, not just the first: a hull can carry three.
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
				var want_at := DB.hull_exhaust_at(h.weight, h.tier, int(t.id), h.manufacturer)
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
