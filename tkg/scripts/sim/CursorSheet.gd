extends RefCounted

## A cursor cannot be screenshotted, so candidates are blitted over four grounds instead.
## Why: docs/why/CursorSheet.md#cursor-sheet

const NAMES: Array[String] = ["reticle", "reticle_hot"]
## Where each one is dropped, in design pixels: hull, sky, drawer, card.
const OVER: Array[Vector2] = [Vector2(150, 190), Vector2(700, 140),
	Vector2(120, 470), Vector2(430, 500)]
const ZOOM := 5


class Sheet extends Control:
	var shots: Array = []
	# Handed in, since an inner class cannot name its holding script without a `class_name`.
	var over: Array = []
	var labels: Array = []
	var zoom: int = 6

	func _draw() -> void:
		# The panel behind the zoom strip, so the big versions are judged
		# against one steady colour rather than against whatever is behind.
		var f := ThemeDB.fallback_font
		var panel := Rect2(Vector2(676, 176), Vector2(268, 336))
		draw_rect(panel, UITheme.PANEL, true)
		draw_rect(panel, UITheme.LINE, false, 1.0)
		for i in shots.size():
			var tex: Texture2D = shots[i]
			for at in over:
				draw_texture(tex, at + Vector2(i * 40, 0))
			# A row each: the strip spaced at 62 px for a 192 px picture drew them over each other.
			var side := float(tex.get_size().y) * float(zoom)
			var big := Vector2(692, 192 + i * (side + 14))
			draw_texture_rect(tex, Rect2(big, Vector2(side, side)), false)
			draw_string(f, big + Vector2(side + 14, side * 0.5),
				String(labels[i]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT,
				-1, UITheme.FS_SMALL, UITheme.ICE)


func run(tree: SceneTree) -> void:
	await tree.process_frame
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_sector()
	for i in 60:
		await RenderingServer.frame_post_draw

	var sheet := Sheet.new()
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.over = OVER
	sheet.labels = NAMES
	sheet.zoom = ZOOM
	for n in NAMES:
		# From disk, not `res://`: candidates are not assets, so import never learns of them.
		var img := Image.new()
		var path := ProjectSettings.globalize_path("res://art/cursors/%s_2x.png" % n)
		if img.load(path) != OK:
			print("  missing %s" % path)
			continue
		sheet.shots.append(ImageTexture.create_from_image(img))
	tree.root.add_child(sheet)
	sheet.move_to_front()
	sheet.queue_redraw()
	for i2 in 6:
		await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png("user://cursors.png")
	print("wrote ", ProjectSettings.globalize_path("user://cursors.png"))
	tree.quit()
