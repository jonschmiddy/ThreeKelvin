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
		if a == "cardshot" or a == "all":
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
	if "all" in argv:
		want = []
		for n in by_name:
			want.append(String(n))

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
		var path := "res://../tools/out/cardshot/%s.png" % _slug(n)
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://../tools/out/cardshot"))
		cut.save_png(path)
		print("  ", n, " -> ", path)
		wrote += 1
		view.queue_free()

	print("cardshot: wrote ", wrote, " of ", want.size())
	tree.quit()


## The filename a card gets. Same rule the card art already uses so a shot and
## its candidates sort next to each other: lowercase, underscores, nothing else.
func _slug(n: String) -> String:
	var out := ""
	for ch in n.to_lower():
		out += ch if ch in "abcdefghijklmnopqrstuvwxyz0123456789" else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.strip_edges().trim_prefix("_").trim_suffix("_")
