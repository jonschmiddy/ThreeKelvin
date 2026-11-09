extends RefCounted

## Not `--headless`: the settle waits on `frame_post_draw`.
## Shows the real card beside candidate art.
## Why: docs/why/CardShot.md#card-shot

## Native by default: art tiles are raw 92x60 upscaled
## by whole numbers, so the card must be raw 112x160.
const SCALE_DEFAULT := 1


func run(tree: SceneTree) -> void:
	await tree.process_frame
	var argv := OS.get_cmdline_user_args()
	var scale := SCALE_DEFAULT
	var want: Array[String] = []
	for a in argv:
		if a == "cardshot" or a == "all" or a == "gallery" or a == "hand" 				or a == "bottom":
			continue
		if String(a).begins_with("scale="):
			scale = maxi(1, int(String(a).trim_prefix("scale=")))
			continue
		want.append(String(a))

	# EVERY card in the game, when asked for `all`. Deliberately not the default:
	# the common use is three or four names and 300 PNGs is not a looking tool.
	var by_name := {}
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		for c in m.resolved_cards():
			by_name[String(c.name)] = c
	# Malfunctions are granted by no module, so walking DB.modules misses all sixteen.
	for row in DB.MALFUNCTIONS:
		var mc := DB.malfunction(row[0])
		by_name[String(mc.name)] = mc
	if "all" in argv:
		want = []
		for n in by_name:
			want.append(String(n))

	# The gallery puts many cards side by side at game
	# scale, where same-grey-box malfunctions show.
	if "gallery" in argv:
		Router.show_cards()
		for i in 6:
			await RenderingServer.frame_post_draw
		# `bottom` scrolls to the end: the malfunctions
		# are the last group and the reason for the shot.
		if "bottom" in argv:
			var sc := _find_scroll(tree.root)
			if sc != null:
				sc.scroll_vertical = 1 << 20
				for i2 in 3:
					await RenderingServer.frame_post_draw
		var shot := tree.root.get_texture().get_image()
		var gpath := "res://../tools/out/cardshot/_gallery.png"
		shot.save_png(gpath)
		print("gallery -> ", ProjectSettings.globalize_path(gpath),
			" (", shot.get_width(), "x", shot.get_height(), ")")
		tree.quit()
		return

	# A hand at game scale: the gallery is module cards
	# only, so malfunctions render only in a combat hand.
	if "hand" in argv:
		var hhost := Control.new()
		hhost.set_anchors_preset(Control.PRESET_FULL_RECT)
		tree.root.add_child(hhost)
		var hbg := ColorRect.new()
		hbg.color = UITheme.VOID
		hbg.set_anchors_preset(Control.PRESET_FULL_RECT)
		hhost.add_child(hbg)
		var step := CardView.CARD_W + 8
		var x0 := int((960 - (want.size() * step - 8)) / 2.0)
		for i in want.size():
			if not by_name.has(want[i]):
				continue
			var cv := CardView.new()
			cv.position = Vector2(x0 + i * step, 540 - CardView.CARD_H - 24)
			hhost.add_child(cv)
			cv.setup(by_name[want[i]] as CardData, true, 1)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var hshot := tree.root.get_texture().get_image()
		var hpath := "res://../tools/out/cardshot/_hand.png"
		hshot.save_png(hpath)
		print("hand -> ", ProjectSettings.globalize_path(hpath))
		tree.quit()
		return

	if want.is_empty():
		print("cardshot: name a card, or `all`. ", by_name.size(), " known.")
		tree.quit()
		return

	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	tree.root.add_child(host)
	# A ground behind the card, as its rounded corners
	# draw none and a clear corner photographs stale.
	var bg := ColorRect.new()
	bg.color = UITheme.VOID
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)

	var wrote := 0
	for n in want:
		if not by_name.has(n):
			print("  no card named ", n)
			continue
		var view := CardView.new()
		view.position = Vector2.ZERO
		host.add_child(view)
		view.setup(by_name[n] as CardData, true, scale)
		# Two frames, not one: the first lays the card
		# out, and `_draw` runs against the settled size.
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var shot := tree.root.get_texture().get_image()
		var w := CardView.CARD_W * scale
		var h := CardView.CARD_H * scale
		var cut := shot.get_region(Rect2i(0, 0, w, h))
		# Named by `art_key()`, not display name: slugging
		# disagreed for every malfunction, writing 13 orphan shots.
		# Why: docs/why/CardShot.md#shot-naming
		var path := "res://../tools/out/cardshot/%s.png" % (by_name[n] as CardData).art_key()
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://../tools/out/cardshot"))
		cut.save_png(path)
		print("  ", n, " -> ", path)
		wrote += 1
		view.queue_free()

	print("cardshot: wrote ", wrote, " of ", want.size())
	tree.quit()


## The first ScrollContainer under a node, depth first. The gallery builds its
## own tree, so the shot has to find the scroller rather than be handed it.
func _find_scroll(n: Node) -> ScrollContainer:
	if n is ScrollContainer:
		return n as ScrollContainer
	for c in n.get_children():
		var got := _find_scroll(c)
		if got != null:
			return got
	return null
