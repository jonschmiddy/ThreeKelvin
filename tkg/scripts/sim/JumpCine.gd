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
		while t0 < (JumpFx.HYPER_REV if sc._view.ship_flare_melts() else SectorScreen.REV_S):
			await tree.process_frame
			t0 += tree.root.get_process_delta_time()
		var fx := sc._view.ship_pulse()
		var step := (fx.life() + 0.1) / float(DEMO_FRAMES) if fx.melts() else DEMO_STEP
		# The hull goes at the peak, exactly as it does in play.
		fx.peaked.connect(func() -> void: art.visible = false, CONNECT_ONE_SHOT)
		var t := 0.0
		for f in DEMO_FRAMES:
			while t < float(f) * step:
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


## The hyperdrive as a film, for reviewing it WITH its sound:
##   godot --path . -- jumpcine film
##
## Frames of the real departure, cropped around the hull and the spark, each
## logged with the moment it was taken, plus the offsets the two clips start
## at. A muxer lays the clips under the frames and makes one file to watch. A
## strip of stills is not a review of a sound, and a sound on its own is not a
## review of whether it lands on the picture.
const FILM_FPS := 30.0

func _film(tree: SceneTree) -> void:
	var sc := Router.current as SectorScreen
	sc._skip()
	for _s in 6:
		await tree.process_frame
	var art := sc._view.ship_view()
	art.visible = true
	art.park()
	art.refresh()
	await tree.process_frame
	var shot0 := tree.root.get_texture().get_image()
	var box := Rect2(art.get_global_rect().position + art.hull_rect().position,
		art.hull_rect().size)
	# The hull and everything thrown off its nose: the spark lands HYPER_DEST
	# of a hull past centre and throws out to 1.15 hull-heights.
	var reach := box.size.y * 1.2
	var x0 := clampi(int(box.position.x) - 24, 0, shot0.get_width() - 2)
	var x1 := clampi(int(box.position.x + box.size.x * (0.5 + JumpFx.HYPER_DEST) + reach) + 16,
		x0 + 2, shot0.get_width())
	var y0 := clampi(int(box.get_center().y - reach) - 8, 0, shot0.get_height() - 2)
	var y1 := clampi(int(box.get_center().y + reach) + 8, y0 + 2, shot0.get_height())
	# EVEN, because H.264 will not take an odd dimension.
	var crop := Rect2i(x0, y0, (x1 - x0) / 2 * 2, (y1 - y0) / 2 * 2)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://film"))

	var log := PackedStringArray()
	var hyper := sc._view.ship_flare_melts()
	var rev := JumpFx.HYPER_REV if hyper else SectorScreen.REV_S
	var total := rev + (JumpFx.LONG_LIFE if hyper else JumpFx.LIFE) + 0.35
	var dclip := art.depart(hyper)
	# The film plays what the game plays, which for a hyperdrive is no roar.
	log.append("depart 0.0000 %s" % ("-" if hyper else String(dclip)))
	var pulsed := false
	var t := 0.0
	var f := 0
	while t < total:
		if not pulsed and t >= rev:
			pulsed = true
			var fx := sc._view.ship_pulse()
			fx.peaked.connect(func() -> void: art.visible = false, CONNECT_ONE_SHOT)
			log.append("pulse %.4f %s" % [t, "hyperjump" if fx.melts() else "-"])
		await RenderingServer.frame_post_draw
		if t >= float(f) / FILM_FPS:
			tree.root.get_texture().get_image().get_region(crop).save_png(
				"user://film/f_%03d.png" % f)
			log.append("frame %d %.4f" % [f, t])
			f += 1
		await tree.process_frame
		t += tree.root.get_process_delta_time()
	log.append("crop %d %d %d %d" % [crop.position.x, crop.position.y,
		crop.size.x, crop.size.y])
	var fa := FileAccess.open("user://film/log.txt", FileAccess.WRITE)
	fa.store_string(String.chr(10).join(log))
	fa.close()
	print("  film: %d frames over %.2f s, crop %s -> %s"
		% [f, t, crop, ProjectSettings.globalize_path("user://film")])
	tree.quit()


## Every ending, as a strip, straight out of the game:
##   godot --path . -- jumpcine endings
##
## Only the part that differs is photographed. Each run SEEKS the flare to the
## middle of the snap rather than sitting through the charge twenty times, so a
## strip is the hull going, the beam running, and the ending.
const END_FRAMES := 32
const END_STEP := 0.030

func _endings(tree: SceneTree) -> void:
	var sc := Router.current as SectorScreen
	sc._skip()
	for _s in 6:
		await tree.process_frame
	var keep_style := JumpFx.style
	var keep_end := JumpFx.ending
	JumpFx.style = JumpFx.STYLES.find(&"hyperdrive")
	var art := sc._view.ship_view()
	art.visible = true
	art.park()
	art.refresh()
	await tree.process_frame
	var shot0 := tree.root.get_texture().get_image()
	var body := art.hull_body()
	var gx := art.get_global_rect().position.x + body.position.x
	var gy := art.get_global_rect().position.y + body.position.y + body.size.y * 0.5
	var x0 := clampi(int(gx) - 12, 0, shot0.get_width() - 2)
	var x1 := clampi(int(gx + body.size.x * (0.5 + JumpFx.HYPER_DEST)) + 96, x0 + 2, shot0.get_width())
	var y0 := clampi(int(gy) - 64, 0, shot0.get_height() - 130)
	var crop := Rect2i(x0, y0, (x1 - x0) / 2 * 2, 128)
	print("  endings crop %s, %d frames at %.0f ms" % [crop, END_FRAMES, END_STEP * 1000.0])
	for i in JumpFx.ENDINGS.size():
		JumpFx.ending = i
		art.visible = true
		art.park()
		art.refresh()
		await tree.process_frame
		art.depart(true)
		var fx := sc._view.ship_pulse()
		fx.seek(JumpFx.CHARGE_S + JumpFx.SNAP_S * 0.5)
		var strip: Image = null
		var t := 0.0
		for f in END_FRAMES:
			while t < float(f) * END_STEP:
				await tree.process_frame
				t += tree.root.get_process_delta_time()
			await RenderingServer.frame_post_draw
			var shot := tree.root.get_texture().get_image()
			if strip == null:
				strip = Image.create(crop.size.x * END_FRAMES, crop.size.y, false, shot.get_format())
			strip.blit_rect(shot, crop, Vector2i(f * crop.size.x, 0))
		var out := "user://ending_%02d_%s.png" % [i, JumpFx.ENDINGS[i]]
		strip.save_png(out)
		print("  %2d  %-10s -> %s" % [i, JumpFx.ENDINGS[i], ProjectSettings.globalize_path(out)])
		while fx.visible:
			await tree.process_frame
	JumpFx.style = keep_style
	JumpFx.ending = keep_end
	tree.quit()


## Every bar look, as a strip, straight out of the game:
##   godot --path . -- jumpcine bars
##
## From partway into the charge -- seeked there, so the whole charge is not sat
## through twelve times -- to the end of the run, which is everywhere the bar is
## on screen: growing on the hull, full at the snap, and running off.
const BAR_FRAMES := 44
const BAR_STEP := 0.040

func _bars(tree: SceneTree) -> void:
	var sc := Router.current as SectorScreen
	sc._skip()
	for _s in 6:
		await tree.process_frame
	var keep_style := JumpFx.style
	var keep_bar := JumpFx.bar
	JumpFx.style = JumpFx.STYLES.find(&"hyperdrive")
	var art := sc._view.ship_view()
	art.visible = true
	art.park()
	art.refresh()
	await tree.process_frame
	var shot0 := tree.root.get_texture().get_image()
	var body := art.hull_body()
	var gx := art.get_global_rect().position.x + body.position.x
	var gy := art.get_global_rect().position.y + body.position.y + body.size.y * 0.5
	var x0 := clampi(int(gx) - 10, 0, shot0.get_width() - 2)
	var x1 := clampi(int(gx + body.size.x * (0.5 + JumpFx.HYPER_DEST)) + 20, x0 + 2, shot0.get_width())
	var y0 := clampi(int(gy) - 64, 0, shot0.get_height() - 130)
	var crop := Rect2i(x0, y0, (x1 - x0) / 2 * 2, 128)
	print("  bars crop %s, %d frames at %.0f ms" % [crop, BAR_FRAMES, BAR_STEP * 1000.0])
	for i in JumpFx.BARS.size():
		JumpFx.bar = i
		art.visible = true
		art.park()
		art.refresh()
		await tree.process_frame
		art.depart(true)
		var fx := sc._view.ship_pulse()
		fx.seek(JumpFx.CHARGE_S * 0.55)
		var strip: Image = null
		var t := 0.0
		for f in BAR_FRAMES:
			while t < float(f) * BAR_STEP:
				await tree.process_frame
				t += tree.root.get_process_delta_time()
			await RenderingServer.frame_post_draw
			var shot := tree.root.get_texture().get_image()
			if strip == null:
				strip = Image.create(crop.size.x * BAR_FRAMES, crop.size.y, false, shot.get_format())
			strip.blit_rect(shot, crop, Vector2i(f * crop.size.x, 0))
		var out := "user://bar_%02d_%s.png" % [i, JumpFx.BARS[i]]
		strip.save_png(out)
		print("  %2d  %-10s -> %s" % [i, JumpFx.BARS[i], ProjectSettings.globalize_path(out)])
		while fx.visible:
			await tree.process_frame
	JumpFx.style = keep_style
	JumpFx.bar = keep_bar
	tree.quit()


## EVERY SPOOL LOOK, as a strip of frames: the hull through the whole charge.
##   godot --path . -- jumpcine spools
##
## The same harness as `bars`, started at the top of the charge instead of partway
## in, since the looks are what the hull does as the spool STARTS. Forty frames
## across CHARGE_S, cropped to the hull and nothing past it.
const SPOOL_FRAMES := 40
const SPOOL_STEP := 0.095

## `rows`, when given, films only `interlace`, once at each of those strengths:
##   godot --path . -- jumpcine interlace
func _spools(tree: SceneTree, rows: Array = []) -> void:
	var sc := Router.current as SectorScreen
	sc._skip()
	for _s in 6:
		await tree.process_frame
	var keep_style := JumpFx.style
	var keep_spool := JumpFx.spool
	var keep_rows := JumpFx.interlace_rows
	JumpFx.style = JumpFx.STYLES.find(&"hyperdrive")
	var art := sc._view.ship_view()
	art.visible = true
	art.park()
	art.refresh()
	await tree.process_frame
	var shot0 := tree.root.get_texture().get_image()
	var body := art.hull_body()
	var gx := art.get_global_rect().position.x + body.position.x
	var gy := art.get_global_rect().position.y + body.position.y + body.size.y * 0.5
	var x0 := clampi(int(gx) - 16, 0, shot0.get_width() - 2)
	var x1 := clampi(int(gx + body.size.x) + 16, x0 + 2, shot0.get_width())
	var y0 := clampi(int(gy) - 56, 0, shot0.get_height() - 114)
	var crop := Rect2i(x0, y0, (x1 - x0) / 2 * 2, 112)
	print("  spools crop %s, %d frames at %.0f ms" % [crop, SPOOL_FRAMES, SPOOL_STEP * 1000.0])
	var runs: Array = []
	if rows.is_empty():
		for i in JumpFx.SPOOLS.size():
			runs.append([i, 1.0, "user://spool_%02d_%s.png" % [i, JumpFx.SPOOLS[i]]])
	else:
		var lace := JumpFx.SPOOLS.find(&"interlace")
		for r in rows:
			runs.append([lace, float(r), "user://interlace_%d.png" % int(round(float(r) * 100.0))])
	for run: Array in runs:
		JumpFx.spool = run[0]
		JumpFx.interlace_rows = run[1]
		art.visible = true
		art.park()
		art.refresh()
		await tree.process_frame
		art.depart(true)
		var fx := sc._view.ship_pulse()
		var strip: Image = null
		var t := 0.0
		var slow := 0
		for f in SPOOL_FRAMES:
			while t < float(f) * SPOOL_STEP:
				await tree.process_frame
				var dt := tree.root.get_process_delta_time()
				if dt > 1.0 / 30.0:
					slow += 1
				t += dt
			await RenderingServer.frame_post_draw
			var shot := tree.root.get_texture().get_image()
			if strip == null:
				strip = Image.create(crop.size.x * SPOOL_FRAMES, crop.size.y, false, shot.get_format())
			strip.blit_rect(shot, crop, Vector2i(f * crop.size.x, 0))
		var out: String = run[2]
		strip.save_png(out)
		print("  %-10s rows %.2f -> %s  (%d frames slower than 30 fps)"
			% [JumpFx.SPOOLS[run[0]], run[1], ProjectSettings.globalize_path(out), slow])
		while fx.visible:
			await tree.process_frame
	JumpFx.style = keep_style
	JumpFx.spool = keep_spool
	JumpFx.interlace_rows = keep_rows
	tree.quit()


## THE WHOLE JUMP, as a film with its sound:
##   godot --path . -- jumpcine whole
##
## Everything between pressing JUMP and the drawer settling, through the real
## Router path -- `begin_jump`, the departure, the commit, the swap, the name
## card, the approach, the drawer -- captured full-frame. Every effect that
## actually plays is taped by `Audio` with the moment it played, so the muxer
## lays the real sounds under the frames: which arrival clip was drawn, whether
## the screen-change tick fired, none of it assumed.
const WHOLE_FPS := 30.0
const WHOLE_TAIL := 1.2

func _whole(tree: SceneTree, to: int) -> void:
	var sc := Router.current as SectorScreen
	sc._skip()
	for _s in 20:
		await tree.process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://whole"))
	var total := (SectorScreen.DEPART_LEAD + JumpFx.HYPER_REV
		+ JumpFx.LONG_LIFE * JumpFx.LONG_PEAK + SectorScreen.CARD_TOTAL
		+ ShipView.ARRIVE_MS / 1000.0 + WHOLE_TAIL)
	var log := PackedStringArray()
	log.append("route %s -> %s" % [MapGen.star_name(Run.node_at()), MapGen.star_name(Run.map[to])])
	Audio.tape.clear()
	Audio.taping = true
	var t0 := Time.get_ticks_msec()
	Router.begin_jump(to)
	var f := 0
	var t := 0.0
	while t < total:
		await RenderingServer.frame_post_draw
		t = float(Time.get_ticks_msec() - t0) / 1000.0
		if t >= float(f) / WHOLE_FPS:
			tree.root.get_texture().get_image().save_png("user://whole/f_%04d.png" % f)
			log.append("frame %d %.4f" % [f, t])
			f += 1
		await tree.process_frame
	Audio.taping = false
	for e in Audio.tape:
		log.append("sfx %s %.4f %.2f %.4f" % [e[0], float(int(e[1]) - t0) / 1000.0,
			float(e[2]), float(e[3])])
	var fa := FileAccess.open("user://whole/log.txt", FileAccess.WRITE)
	fa.store_string(String.chr(10).join(log))
	fa.close()
	print("  whole: %d frames over %.2f s, %d sounds -> %s"
		% [f, t, Audio.tape.size(), ProjectSettings.globalize_path("user://whole")])
	tree.quit()


func run(tree: SceneTree) -> void:
	await tree.process_frame
	Rng.forced = 4242
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("seed="):
			Rng.forced = int((a as String).substr(5))
	# weight=heavy or weight=light to photograph another hull; medium by default.
	# The warp line sat above the middle of a heavy, which a medium-only harness
	# could never show.
	var weight := int(HullData.Weight.MEDIUM)
	for a in OS.get_cmdline_user_args():
		if a == "weight=heavy":
			weight = int(HullData.Weight.HEAVY)
		elif a == "weight=light":
			weight = int(HullData.Weight.LIGHT)
	Run.start_new_run(&"korvan", weight)

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
	if "film" in OS.get_cmdline_user_args():
		await _film(tree)
		return
	if "endings" in OS.get_cmdline_user_args():
		await _endings(tree)
		return
	if "bars" in OS.get_cmdline_user_args():
		await _bars(tree)
		return
	if "interlace" in OS.get_cmdline_user_args():
		await _spools(tree, [1.0, 0.35, 0.20, 0.10])
		return
	if "spools" in OS.get_cmdline_user_args():
		await _spools(tree)
		return
	if "whole" in OS.get_cmdline_user_args():
		await _whole(tree, to)
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
