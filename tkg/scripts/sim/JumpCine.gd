extends RefCounted

## The jump, photographed frame by frame:
##   godot --path . -- jumpcine [seed=N]
##
## NEEDS A WINDOW, like every shot tool here: under `--headless` the dummy
## display server never emits `frame_post_draw`, so nothing is captured and it
## looks exactly like a hang.
##
## AND IT IS DELIBERATELY NOT CALLED `jumpshot`. `Router.animating()` returns
## false for any argument ending in "shot", which is what keeps the screenshot
## tools from photographing half-finished tweens -- and the whole subject here
## IS the tweens. A shot tool cannot see this sequence by construction, so this
## one is named out of that rule rather than fighting it.
##
## IT EXISTS BECAUSE A CINEMATIC IS A LAYOUT THAT MOVES. `sectorshot` proves the
## end state and says nothing about the seven seconds before it: whether the
## drawer is parked below the floor while the ship flies in, whether the name
## card is still up when the hull arrives, whether anything is drawn in the band
## the drawer will occupy. Those are questions about particular frames, and the
## only honest way to answer them is to look at those frames.

const SHOTS := {
	 0.30: "01_rev_early",
	 0.78: "02_rev_moving",
	 1.05: "03_rev_late",
	 1.60: "03_card_in",
	 2.60: "04_card_held",
	 3.60: "05_card_gone",
	 5.00: "06_flying_in",
	 7.20: "07_coasting",
	 8.50: "08_parked_shut",
	 9.30: "09_drawer_open",
}


func _snap(tree: SceneTree, name: String) -> void:
	var p := "user://cine_%s.png" % name
	tree.root.get_texture().get_image().save_png(p)
	print("  wrote %s" % ProjectSettings.globalize_path(p))


## What the screen is made of at this instant, in numbers rather than pixels --
## so a regression has something to fail on and not only something to look at.
func _line(at: float, name: String) -> void:
	var sc := Router.current as SectorScreen
	if sc == null:
		print("  %5.2fs %-16s  (no sector screen: %s)"
			% [at, name, Router.current])
		return
	var art := sc._view.ship_view()
	print("  %5.2fs %-16s  phase %d  ship x %+6.1f vis %s  card %s"
			% [at, name, sc._phase,
			   art.position.x if art != null else 0.0,
			   "y" if art != null and art.visible else "n",
			   "%.2f" % sc._card.modulate.a if sc._card != null else "-"]
		+ "  drawer y %+6.1f of %.0f  band %.0f  bleed %.0f  viewend %.0f/%.0f"
			% [sc._quiet_wrap.position.y, sc._quiet_wrap.size.y,
			   sc._quiet_holder.size.y, sc._view._bleed,
			   sc._view.get_global_rect().end.y, sc.get_global_rect().end.y])


## Every jump style, as a strip of frames, straight out of the game.
##
## ONE STRIP PER STYLE, frames laid left to right, cropped to the hull so the
## flare fills the picture rather than sitting in a corner of a 960x540 screen.
## Twenty of these is something you can look at side by side and choose from;
## twenty descriptions of light is not.
const DEMO_W := 416
const DEMO_H := 176
const DEMO_FRAMES := 28
const DEMO_STEP := 0.032

func _demo(tree: SceneTree) -> void:
	var sc := Router.current as SectorScreen
	# ON THE HULL, not on the slot it floats in -- the same distinction the
	# flare itself had to learn. `hull_rect()` is in the view's own coordinates.
	# STRAIGHT TO THE END OF THE ARRIVAL FIRST. The first system of a run plays
	# the whole sequence now, so without this the name card is still up across
	# the middle of every strip.
	sc._skip()
	for _s in 4:
		await tree.process_frame
	var art0 := sc._view.ship_view()
	var box := Rect2(art0.get_global_rect().position + art0.hull_rect().position,
		art0.hull_rect().size)
	# LEADING THE SHIP. It is already a hundred pixels right by the time the
	# column fires and still accelerating, so a crop centred on where it parks
	# photographs the space it has left.
	var lead := 0.0 if sc._view.ship_flare_melts() else ShipView.DEPART_OVER * 0.62
	var org := Vector2i(
		clampi(int(box.get_center().x + lead) - DEMO_W / 2,
			0, int(tree.root.size.x) - DEMO_W),
		clampi(int(box.get_center().y) - DEMO_H / 2,
			0, int(tree.root.size.y) - DEMO_H))
	print("  hull_rect %s  art.size %s  art.gpos %s  dest-> box-local %.0f"
		% [art0.hull_rect(), art0.size, art0.get_global_rect().position,
		   art0.hull_rect().size.x * (0.5 + JumpFx.HYPER_DEST)])
	print("  crop %s  %dx%d  %d frames at %.0f ms"
		% [org, DEMO_W, DEMO_H, DEMO_FRAMES, DEMO_STEP * 1000.0])

	for i in JumpFx.STYLES.size():
		JumpFx.style = i
		var art := sc._view.ship_view()
		art.visible = true
		art.park()
		art.refresh()
		# Format taken from the viewport rather than assumed: `blit_rect` wants
		# both images in the same one and a guess here is twenty silent frames.
		var strip: Image = null
		# THE REAL DEPARTURE, not a column over a parked ship. The hull is
		# accelerating out from under the flare by the time it is taken, and
		# that is most of what these are being compared on.
		art.depart(sc._view.ship_flare_melts())
		var t0 := 0.0
		while t0 < SectorScreen.REV_S:
			await tree.process_frame
			t0 += tree.root.get_process_delta_time()
		var fx := sc._view.ship_pulse()
		# The hull goes at the peak, exactly as it does in play.
		fx.peaked.connect(func() -> void: art.visible = false, CONNECT_ONE_SHOT)
		var t := 0.0
		for f in DEMO_FRAMES:
			while t < float(f) * DEMO_STEP:
				await tree.process_frame
				t += tree.root.get_process_delta_time()
			await RenderingServer.frame_post_draw
			var shot := tree.root.get_texture().get_image()
			if strip == null:
				strip = Image.create(DEMO_W * DEMO_FRAMES, DEMO_H, false,
					shot.get_format())
			strip.blit_rect(shot, Rect2i(org, Vector2i(DEMO_W, DEMO_H)),
				Vector2i(f * DEMO_W, 0))
		var out := "user://jumpfx_%02d_%s.png" % [i, JumpFx.STYLES[i]]
		strip.save_png(out)
		print("  %2d  %-9s -> %s" % [i, JumpFx.STYLES[i],
			ProjectSettings.globalize_path(out)])
		# Let the last one finish before the next begins.
		for _w in 14:
			await tree.process_frame
	JumpFx.style = 0
	tree.quit()


func run(tree: SceneTree) -> void:
	await tree.process_frame
	Rng.forced = 4242
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("seed="):
			Rng.forced = int((a as String).substr(5))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))

	# Somewhere to go. The first node that is a plain SYSTEM and in range, so
	# the drawer photographed is the full one rather than a bookend's.
	var to := -1
	for n: MapGen.MapNode in Run.map:
		if n.index != Run.at and n.type == MapGen.NodeType.SYSTEM \
				and Run.can_jump_to(n):
			to = n.index
			break
	if to < 0:
		print("jumpcine: nowhere in range on seed %d" % Rng.forced)
		tree.quit()
		return

	Router.show_sector()
	for i in 10:
		await tree.process_frame
	if "demo" in OS.get_cmdline_user_args():
		await _demo(tree)
		return
	print("jumpcine: %s -> %s"
		% [MapGen.star_name(Run.node_at()), MapGen.star_name(Run.map[to])])
	Router.begin_jump(to)

	var t := 0.0
	var keys := SHOTS.keys()
	keys.sort()
	for at: float in keys:
		while t < at:
			await tree.process_frame
			t += tree.root.get_process_delta_time()
		await RenderingServer.frame_post_draw
		_line(t, String(SHOTS[at]))
		_snap(tree, String(SHOTS[at]))
	tree.quit()
