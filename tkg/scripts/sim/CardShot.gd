extends RefCounted

## One card, as the game draws it today, cropped to the card:
##
##   godot --path . -- cardshot "Ripple Fire" "Full Auto"
##   godot --path . -- cardshot all
##
## NOT `--headless`, for the reason ShipShot records at length: the settle waits
## on `frame_post_draw`, which the dummy display server never emits.
##
## WHY THIS EXISTS. Card art is being chosen against a baseline nobody can see.
## Every candidate illustration is judged on a contact sheet as a bare 92x60
## rectangle, but the thing it REPLACES is `CardView._type_glyph()` drawing into
## that window under a name, an energy pip and three lines of rules text. A
## picture that looks thin on a sheet can still be the better card, and a picture
## that looks rich on a sheet can fight the text under it. So: photograph the
## card, put it beside the options, and let the comparison be the real one.
##
## Cards are looked up BY NAME because that is what a card has. There is no card
## id in the schema — CardData carries `name` and `source_id` and nothing else
## that identifies it — so the argument is the display name, quoted.

## NATIVE by default, not the inspect size. A shot of a card exists to be put
## beside candidate art on a review bench, and the art tiles there are the raw
## 92x60 upscaled by whole numbers — so the card has to be raw 112x160 too, or
## the two halves of the comparison are at different scales at every zoom but
## one. `scale=2` when the question is legibility rather than composition.
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
	# MALFUNCTIONS ARE NOT GRANTED BY A MODULE, so walking DB.modules misses all
	# sixteen of them -- and they are a fifth of the cards that still need art.
	# `ArtCheck._cards` already has to make the same second pass; this is the
	# same list read the same way.
	for row in DB.MALFUNCTIONS:
		var mc := DB.malfunction(row[0])
		by_name[String(mc.name)] = mc
	if "all" in argv:
		want = []
		for n in by_name:
			want.append(String(n))

	# THE GALLERY, PHOTOGRAPHED:  godot --path . -- cardshot gallery
	# A card on its own is not the question a hand asks. The gallery is the one
	# screen that puts many cards beside each other at game scale, which is
	# where "these four malfunctions are the same grey box" is visible and where
	# a card that reads at 1x is told apart from one that does not.
	if "gallery" in argv:
		Router.show_cards()
		for i in 6:
			await RenderingServer.frame_post_draw
		# `bottom` scrolls to the end before the shutter. The malfunctions are
		# the last group on the page and were the reason for adding them, so a
		# capture that only ever shows the top of the list cannot show them.
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

	# A HAND, AT GAME SCALE:  godot --path . -- cardshot hand "Slag" "Dross" ...
	# The gallery is module cards only, so a malfunction never appears in it --
	# the one place they render is a combat hand. This lays the named cards out
	# in a row on the real 960x540 viewport using the game's own CardView at
	# _s = 1, which is the size a player actually reads them at.
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
	# A ground BEHIND the card, because the card does not draw one under its own
	# rounded corners and a transparent corner photographs as whatever the root
	# viewport last had in it.
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
		# TWO frames, not one. The first lays the card out; `_draw` runs against
		# the size it settled on, and a single frame photographs the frame before
		# the labels have been placed.
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var shot := tree.root.get_texture().get_image()
		var w := CardView.CARD_W * scale
		var h := CardView.CARD_H * scale
		var cut := shot.get_region(Rect2i(0, 0, w, h))
		# NAMED BY art_key(), NOT by the display name. Every other tool in this
		# pipeline -- the manifest, design_sheet.py, bench.py, the installed
		# sprite -- keys on art_key. Slugging the name agreed with it by luck
		# for module cards ("Rack and Load" -> rack_and_load) and disagreed for
		# every malfunction ("Hairline Crack" -> hairline_crack, key `hairline`),
		# so thirteen shots were written where nothing would look for them.
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
