extends RefCounted

## The station, photographed. `godot --path . -- stationshot [maker=solari]`
##
## Same reason ChartShot and ShipShot exist, and one more besides: `-- station`
## opens this screen but nothing has ever taken a picture of it, so the busiest
## screen in the game is the one every change to it was judged on by memory. The
## header alone carries two documented layout disasters -- an autowrapping label
## that collapsed into a column, and a non-wrapping one that grew the screen to
## 983 pixels inside a 960 window -- and both were found by looking.
##
## NOT HEADLESS. The dummy display server never emits `frame_post_draw`, so a
## headless run of this hangs and looks exactly like a crash.
func run(tree: SceneTree) -> void:
	await tree.process_frame

	# `maker=none` photographs a station NOBODY holds, which is the case the
	# header has to get right by omission rather than by drawing -- lawless space
	# has no berth, and a blank flag there would read as a manufacturer with no
	# mark instead of as an absence of manufacturers.
	var maker := &"solari"
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("maker="):
			var want := StringName((a as String).substr(6))
			if want == &"none" or DB.manufacturers.has(want):
				maker = want
			else:
				print("  no manufacturer '%s' -- keeping %s" % [want, maker])

	Run.start_new_run(&"korvan" if maker == &"none" else maker, 1)

	# The same state `-- station` builds, so the two flags photograph one screen
	# rather than two. A shot of a state nothing else ever reaches is evidence
	# about nothing.
	var here: MapGen.MapNode = Run.node_at()
	here.type = MapGen.NodeType.STATION
	here.development = MapGen.Development.CITY
	here.security = 4
	# Two statements rather than a ternary: `berths` is typed, and an untyped
	# empty array will not assign to it.
	here.berths.clear()
	here.manufacturer = &""
	if maker != &"none":
		here.berths.append(maker)
		here.manufacturer = maker
	here.danger = 5
	for i in 3:
		Run.stow(LootGen.roll_module(4 + i, &"", true))
	for seeded in [&"exotic", &"exotic", &"relic"]:
		Run.stow(MaterialData.of(MaterialTable.by_id(seeded)))
	# FOUR OF THE BERTH'S OWN PARTS BOLTED ON, so the set-bonus chip is lit.
	# A fresh run counts one -- the hull -- and the chip appears at three, so a
	# shot of the state you get for free is a shot of the chip not existing.
	# `sets=N` asks for a different count; five lights the upper tier.
	var want := 4
	for a2 in OS.get_cmdline_user_args():
		if (a2 as String).begins_with("sets="):
			want = int((a2 as String).substr(5))
	if maker != &"none":
		var fitted := 0
		for mid in DB.modules:
			if fitted >= want:
				break
			var md: ModuleData = DB.modules[mid]
			if md.manufacturer != maker:
				continue
			Run.install_module(md.duplicate(true) as ModuleData)
			fitted += 1
		print("  %d %s parts fitted · set count %d" % [fitted,
			DB.short_name(DB.manufacturer_name(maker)), Run.manufacturer_count(maker)])

	Run.hp = maxi(1, Run.max_hp() - 12)
	Run.add_dross(3)
	Router.show_station()

	# Thirty frames rather than one. The screen builds four panels, and a shot
	# taken on the frame after `show_station` catches half of them unsized --
	# the same reason `fittest` waits two frames before it samples a redraw.
	for i in 30:
		await RenderingServer.frame_post_draw

	# THE BAR'S OWN WIDTH, printed rather than eyeballed. HudBar's header records
	# that the row was 983px at a 960 window with dev mode on, and that the fix
	# was four pixels of separation per gap -- so anything added to it since is
	# spending a margin measured in single figures. A screenshot shows you the
	# last tab is short; only this says by how much.
	if Router.hud != null and Router.hud._row != null:
		var need: float = Router.hud._row.get_combined_minimum_size().x
		var have: float = Router.hud.size.x
		print("  hud row wants %.0f of %.0f%s" % [need, have,
			"  <-- CLIPPED by %.0f" % (need - have) if need > have else ""])

	print("  %s · %s" % ["no berth" if maker == &"none"
		else DB.manufacturer_name(maker) + " berth",
		MapGen.development_name(here.development)])
	var path := "user://station_%s.png" % maker
	tree.root.get_texture().get_image().save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))
	tree.quit()
