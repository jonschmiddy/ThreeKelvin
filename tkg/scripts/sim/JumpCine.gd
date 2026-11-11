extends RefCounted

## Needs a window: `--headless` never emits `frame_post_draw`, so nothing is captured.
## Not named `*shot`: `Router.animating()` is false for those, which would hide the tweens.
## Why: docs/why/JumpCine.md#jump-cinematic

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


## One strip per style, cropped to the hull, so twenty styles can be compared side by side.
## Why: docs/why/JumpCine.md#jump-strips
const DEMO_W := 416
const DEMO_H := 176
const DEMO_FRAMES := 28
const DEMO_STEP := 0.032

func _demo(tree: SceneTree) -> void:
	var sc := Router.current as SectorScreen
	# On the hull, not its slot. Skip to the arrival's
	# end first, or the name card covers every strip.
	sc._skip()
	for _s in 4:
		await tree.process_frame
	var art0 := sc._view.ship_view()
	var box := Rect2(art0.get_global_rect().position + art0.hull_rect().position,
		art0.hull_rect().size)
	# Lead the ship: it is already 100 px right and accelerating, so a centred crop misses it.
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
		# The real departure, not a column over a parked
		# ship: the hull is accelerating out of the flare.
		art.depart(sc._view.ship_flare_melts())
		var t0 := 0.0
		while t0 < (JumpFx.HYPER_REV if sc._view.ship_flare_melts() else JumpDirector.REV_S):
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


## A film with its sound: stills do not review a sound, nor a sound the picture.
## Why: docs/why/JumpCine.md#jump-film
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
	var rev := JumpFx.HYPER_REV if hyper else JumpDirector.REV_S
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


## Seeks the flare to the snap's middle instead of sitting through the charge twenty times.
## Why: docs/why/JumpCine.md#ending-strips
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


## Seeks to partway into the charge, so the whole charge is not sat through twelve times.
## Why: docs/why/JumpCine.md#bar-strips
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


## Started at the top of the charge, as the looks are what the hull does as the spool starts.
## Why: docs/why/JumpCine.md#spool-strips
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


## Real Router path, full frame, every frame at the film's own 60 fps (`--fixed-fps 60`), every
## effect taped by `Audio` so no sound is assumed; `tools/dev/jump_compare.py` muxes the frames
## with the taped cues and lays them beside the approved film:
##   render.sh --path tkg --fixed-fps 60 -- jumpcine whole film=r12 [out=<dir>]
## Why: docs/why/JumpCine.md#whole-jump-film
const WHOLE_FPS := 60.0
const WHOLE_TAIL := 1.5

func _whole(tree: SceneTree, to: int) -> void:
	var sc := Router.current as SectorScreen
	sc._skip()
	for _s in 20:
		await tree.process_frame
	var film := Harness.arg("film", "")
	if film != "":
		JumpRegistry.forced = StringName(film)
	var dir := Harness.arg("out", "user://whole")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var total := 10.0 + WHOLE_TAIL
	var log := PackedStringArray()
	log.append("route %s -> %s" % [MapGen.star_name(Run.node_at()), MapGen.star_name(Run.map[to])])
	log.append("film %s" % JumpRegistry.pick(Run.jumps))
	Audio.tape.clear()
	Audio.taping = true
	var t0 := GameClock.now()
	Router.begin_jump(to)
	var f := 0
	var t := 0.0
	var vp := GameShell.input_target(tree)
	var wall := PackedFloat32Array()
	var gpu := PackedFloat32Array()
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	var last_us := Time.get_ticks_usec()
	while t < total:
		await RenderingServer.frame_post_draw
		var now_us := Time.get_ticks_usec()
		wall.append(float(now_us - last_us) / 1000.0)
		gpu.append(float(RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid())))
		last_us = now_us
		t = GameClock.now() - t0
		if t >= float(f) / WHOLE_FPS - 1e-4:
			vp.get_texture().get_image().save_png("%s/f_%04d.png" % [dir, f])
			log.append("frame %d %.4f %s" % [f, t, Router.current.get_script().resource_path.get_file()])
			f += 1
		await tree.process_frame
	Audio.taping = false
	for e in Audio.tape:
		log.append("sfx %s %.4f from %.4f frame %d" % [e[0], float(e[4]) - t0, float(e[7]), int(e[5])])
	# the wall clock per frame (the png save included, so a ceiling, not the film's cost)
	var sorted := wall.duplicate()
	sorted.sort()
	if sorted.size() > 10:
		log.append("wall ms per frame: median %.1f  p95 %.1f  max %.1f (png saves included)" % [
			sorted[sorted.size() / 2], sorted[int(float(sorted.size()) * 0.95)], sorted[sorted.size() - 1]])
		print("  " + log[log.size() - 1])
		var g2 := gpu.duplicate()
		g2.sort()
		log.append("gpu ms per frame (the game viewport): median %.2f  p95 %.2f  max %.2f" % [
			g2[g2.size() / 2], g2[int(float(g2.size()) * 0.95)], g2[g2.size() - 1]])
		print("  " + log[log.size() - 1])
	var fa := FileAccess.open("%s/log.txt" % dir, FileAccess.WRITE)
	fa.store_string(String.chr(10).join(log))
	fa.close()
	print("  whole: %d frames over %.2f s, %d sounds -> %s"
		% [f, t, Audio.tape.size(), ProjectSettings.globalize_path(dir)])
	tree.quit()


## Every landed film's strip frames (the approved strips' moments) in one run, for
## `tools/dev/jump_compare.py --strips`:  render.sh --path tkg --fixed-fps 60 -- jumpcine films out=<dir>
## Why: docs/why/JumpCine.md#film-strips
const STRIP_TS := {
	&"r12": [0.5, 1.84, 2.25, 2.9, 3.6, 4.3, 4.95, 5.5, 5.8, 6.0, 6.117, 6.6],
	&"r4": [0.5, 1.3, 2.2, 3.0, 4.0, 4.85, 5.017, 5.08, 5.2, 5.8, 6.3, 9.5],
	&"r9": [0.3, 1.9, 2.7, 3.4, 4.1, 4.8, 5.6, 6.0, 6.167, 6.4, 7.4, 9.5],
	&"r2": [0.3, 1.4, 2.6, 3.15, 3.9, 4.35, 4.7, 5.15, 5.5, 5.85, 5.95, 7.0],
}

func _films(tree: SceneTree) -> void:
	var dir := Harness.arg("out", "user://films")
	var vp := GameShell.input_target(tree)
	for id in JumpRegistry.ALL:
		var sc := Router.current as SectorScreen
		sc._skip()
		for _s in 20:
			await tree.process_frame
		var to := -1
		for n: MapGen.MapNode in Run.map:
			if n.index != Run.at and n.type == MapGen.NodeType.SYSTEM and Run.can_jump_to(n):
				n.ambush_rolled = true
				n.ambush_pending = false
				to = n.index
				break
		if to < 0:
			print("  films: nowhere to jump to for %s" % id)
			break
		var sub := "%s/%s" % [dir, id]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sub))
		JumpRegistry.forced = id
		var ts: Array = STRIP_TS[id]
		var t0 := GameClock.now()
		Router.begin_jump(to)
		var next := 0
		var f := 0
		while next < ts.size() and GameClock.now() - t0 < 12.0:
			await RenderingServer.frame_post_draw
			var t := GameClock.now() - t0
			if t >= float(ts[next]) - 1e-4:
				vp.get_texture().get_image().save_png("%s/f_%04d.png" % [sub, int(round(float(ts[next]) * 60.0))])
				next += 1
			f += 1
			await tree.process_frame
		print("  films: %s, %d frames -> %s" % [id, next, ProjectSettings.globalize_path(sub)])
		for _s in 30:
			await tree.process_frame
		Router.show_local()
		for _s in 10:
			await tree.process_frame
	tree.quit()


## Asks what is still playing after a skip: `Audio.tape`
## records starts only, so a lingering warp left no mark.
## Why: docs/why/JumpCine.md#hush-test
const HUSH_WAIT := 4.0
const HUSH_SETTLE := 0.45

func _voices_on() -> PackedStringArray:
	var on := PackedStringArray()
	for p in Audio._sfx:
		if p.playing:
			on.append(String(p.get_meta(&"cue", &"?")))
	return on

func _hush(tree: SceneTree, to: int) -> void:
	var sc := Router.current as SectorScreen
	sc._skip()
	for _s in 20:
		await tree.process_frame

	Router.begin_jump(to)
	# Wait for the warp itself, not a fixed delay, which
	# would be a third copy of the timing arithmetic.
	var t0 := Time.get_ticks_msec()
	var heard := false
	while float(Time.get_ticks_msec() - t0) / 1000.0 < HUSH_WAIT:
		await tree.process_frame
		for v in _voices_on():
			if v.begins_with("jump_"):
				heard = true
		if heard:
			break
	if not heard:
		print("  hush: FAIL -- no jump cue ever played, so nothing was tested")
		tree.quit(1)
		return
	var at := float(Time.get_ticks_msec() - t0) / 1000.0
	print("  hush: a jump cue sounding at %.2f s, skipping" % at)

	var live := Router.current as SectorScreen
	if live != null:
		live._skip()
	var t1 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t1) / 1000.0 < HUSH_SETTLE:
		await tree.process_frame
	var still := _voices_on()
	if still.is_empty():
		print("  hush: PASS -- nothing sounding %.2f s after the skip" % HUSH_SETTLE)
		tree.quit()
	else:
		print("  hush: FAIL -- still playing %s" % ", ".join(still))
		tree.quit(1)


func run(tree: SceneTree) -> void:
	await tree.process_frame
	Rng.forced = 4242
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("seed="):
			Rng.forced = int((a as String).substr(5))
	# weight=heavy or light photographs another hull; the warp line sat above a heavy's middle.
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
	# SECTOR IS THE SYSTEM MAP NOW, and the jump leaves from LOCAL: the
	# departure films below need the side-on screen (Oct 13).
	if not (Router.current is SectorScreen):
		Router.show_local()
		for i2 in 20:
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
	if "hush" in OS.get_cmdline_user_args():
		await _hush(tree, to)
		return
	if "whole" in OS.get_cmdline_user_args():
		await _whole(tree, to)
		return
	if "films" in OS.get_cmdline_user_args():
		await _films(tree)
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
