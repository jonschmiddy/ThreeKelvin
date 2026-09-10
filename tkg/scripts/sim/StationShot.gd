extends RefCounted

## The station, photographed. `godot --path . -- stationshot [manufacturer=solari]`
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

	# `manufacturer=none` photographs a station NOBODY holds, which is the case the
	# header has to get right by omission rather than by drawing -- lawless space
	# has no berth, and a blank flag there would read as a manufacturer with no
	# mark instead of as an absence of manufacturers.
	# A COMMA LIST, because a station can be held by up to THREE and the rail
	# sizes its flags to how many are flying. `MapGen` wants three on 35% of
	# cities and 60% of capitals, so the contested case is common -- and it is
	# exactly the case no amount of clicking will reliably reach, which is what
	# this tool is for.
	#
	#   manufacturer=solari              one berth
	#   manufacturer=solari,cygnet       contested
	#   manufacturer=solari,cygnet,korvan   three, at the smaller flag
	var berths: Array[StringName] = [&"solari"]
	for a in OS.get_cmdline_user_args():
		if not (a as String).begins_with("manufacturer="):
			continue
		var arg := (a as String).substr(13)
		if arg == "none":
			berths = []
			continue
		var want: Array[StringName] = []
		for piece in arg.split(",", false):
			var id := StringName(piece.strip_edges())
			if DB.manufacturers.has(id):
				want.append(id)
			else:
				print("  no manufacturer '%s' -- skipped" % id)
		if not want.is_empty():
			berths = want
	var berth: StringName = berths[0] if not berths.is_empty() else &"none"

	Run.start_new_run(&"korvan" if berths.is_empty() else berths[0], 1)

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
	for id in berths:
		here.berths.append(id)
	if not berths.is_empty():
		here.manufacturer = berths[0]
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
	if berth != &"none":
		var fitted := 0
		for mid in DB.modules:
			if fitted >= want:
				break
			var md: ModuleData = DB.modules[mid]
			if md.manufacturer != berth:
				continue
			Run.install_module(md.duplicate(true) as ModuleData)
			fitted += 1
		print("  %d %s parts fitted · set count %d" % [fitted,
			DB.short_name(DB.manufacturer_name(berth)), Run.manufacturer_count(berth)])

	Run.hp = maxi(1, Run.max_hp() - 12)
	Run.add_dross(3)

	# `full` PHOTOGRAPHS THE BUSY CASE, the same one `-- station full` plays.
	#
	# Without it the Yard's hull is a 75% roll and the shelf is whatever the node
	# happened to stock -- so one shot in four of the shipyard is a picture of
	# the empty-berth line, and a shot of a full shelf is luck. The odds are
	# balance and are left alone; this forces the state, exactly as the playable
	# flag does.
	if "full" in OS.get_cmdline_user_args():
		while not Run.hold_full() and Run.cargo.size() < 40:
			Run.stow(LootGen.roll_module(5, &"", true))
		Run.add_credits(900)
		here.stocked = true
		for i in 5:
			here.shop.append(LootGen.roll_module(5 + i, &"", true))
		here.shop_hull = LootGen.roll_hull(7)
		print("  full: hold %d · shelf %d · hull on the blocks"
			% [Run.cargo.size(), here.shop.size()])

	# `-- stationshot full moving` photographs MOVING DAY: the state one click
	# after TAKE IT, with both ships drawn and the leftovers still on the old
	# one. Reached by actually buying the hull rather than by posing the screen,
	# so what the shot shows is what the flow produces.
	if "moving" in OS.get_cmdline_user_args():
		var offer: HullData = here.shop_hull
		if offer == null:
			offer = LootGen.roll_hull(7)
		Run.transfer_to_hull(offer)
		print("  moving: %d stowed, %d still aboard the %s" % [Run.cargo.size(),
			Run.pad.size(), Run.old_hull.name if Run.old_hull != null else "?"])
		Router.show_transfer()
	else:
		Router.show_station()

	# `-- stationshot full purge` opens the fault picker, which is a modal and so
	# unreachable by any flag that only chooses a deck.
	if "purge" in OS.get_cmdline_user_args():
		var scr := Router.current as StationScreen
		if scr != null:
			scr._open_purge()

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

	print("  %s · %s" % ["no berth" if berth == &"none"
		else DB.manufacturer_name(berth) + " berth",
		MapGen.development_name(here.development)])
	var path := "user://station_%s.png" % berth
	tree.root.get_texture().get_image().save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))
	tree.quit()
