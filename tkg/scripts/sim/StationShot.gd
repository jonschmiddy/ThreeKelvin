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
	# `view=<id>` and `door=<id>`: what the shop's window and door show, instead
	# of whatever this run's seed picks. For judging a view IN its window, which
	# is the only place a view is ever seen.
	for a3 in OS.get_cmdline_user_args():
		var s3 := a3 as String
		if s3.begins_with("view="):
			StationRoom.forced_views[&"window"] = StringName(s3.substr(5))
		elif s3.begins_with("door="):
			StationRoom.forced_views[&"door"] = StringName(s3.substr(5))
		elif s3.begins_with("room="):
			# One of the fifteen by slug (`capital_stone`), whatever the level
			# and seed would pick. `dev=` still sets the station's level.
			ShopScene.forced_room = s3.substr(5)
		elif s3 == "lights=off":
			ShopScene.fullbright = true
		elif s3 == "people=0":
			ShopScene.no_people = true
		elif s3 == "motes=0":
			ShopScene.no_motes = true
		elif s3 == "steady":
			ShopScene.steady = true
		elif s3 == "marks=bench":
			ShopScene.lit_marks = false
		elif s3.begins_with("clock="):
			ShopScene.pin_clock_ms = float(s3.substr(6))
		elif s3.begins_with("backdrop="):
			StationRoom.forced_views[&"backdrop"] = StringName(s3.substr(9))

	Run.start_new_run(&"korvan" if berths.is_empty() else berths[0], 1)

	# The same state `-- station` builds, so the two flags photograph one screen
	# rather than two. A shot of a state nothing else ever reaches is evidence
	# about nothing.
	var here: MapGen.MapNode = Run.node_at()
	here.type = MapGen.NodeType.STATION
	here.development = MapGen.Development.CITY
	# `dev=<level>` (unclaimed, outpost, settlement, city, capital): photograph a
	# station at that level -- the backdrop is drawn from its level's pool.
	for a5 in OS.get_cmdline_user_args():
		if (a5 as String).begins_with("dev="):
			var lv := (a5 as String).substr(4).to_upper()
			if MapGen.Development.has(lv):
				here.development = MapGen.Development[lv]
			else:
				print("  no development level '%s' -- CITY" % lv)
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
		# THE SHELF THE GAME WOULD STOCK, at its ceiling: sixteen cells of parts
		# and no more columns than the rack has, the rule
		# `StationScreen._stock_up` uses. `full` photographs the busy case, so it
		# takes the top of the band rather than rolling one. Five parts
		# regardless was a shelf no station has.
		var cells := StationScreen.SHOP_CELLS
		var cols := StationScreen.SHOP_COLS
		var spins := 0
		while cells > 0 and cols > 0 and spins < 16:
			spins += 1
			var part := LootGen.roll_module(5 + spins, &"", true)
			var took := maxi(1, part.size.x) * maxi(1, part.size.y)
			if took > cells or maxi(1, part.size.x) > cols:
				continue
			cells -= took
			cols -= maxi(1, part.size.x)
			here.shop.append(part)
		here.shop_hull = LootGen.roll_hull(7)
		print("  full: hold %d · shelf %d · hull on the blocks"
			% [Run.cargo.size(), here.shop.size()])
	# `stock=N` cuts the shelf to N parts. `full` stocks five, which is a
	# Cosmopolitan hub's shelf; every other station stocks three, and the rack
	# sizes itself to its stock -- so the ordinary shop needs asking for.
	for a4 in OS.get_cmdline_user_args():
		if (a4 as String).begins_with("stock="):
			var keep := int((a4 as String).substr(6))
			while here.shop.size() > keep:
				here.shop.pop_back()

	# `-- stationshot full moving` photographs MOVING DAY: the state one click
	# after TAKE IT, with both ships drawn and the leftovers still on the old
	# one. Reached by actually buying the hull rather than by posing the screen,
	# so what the shot shows is what the flow produces.
	# `-- stationshot full ship=BLUEBIRD` flies a NAMED ship.
	#
	# A custom name is the one piece of state no fixture reached, and it is
	# exactly the state that catches a screen printing `hull.name` where it
	# should print `Run.display_name()` -- which the Shipyard's own berth label
	# was doing until this flag showed it.
	#
	# SET BEFORE THE SCREEN IS BUILT. Parsed after `show_station` the first time,
	# which proved nothing at all: the deck had already drawn itself off the old
	# value and no refresh had been asked for.
	for a in OS.get_cmdline_user_args():
		if not (a as String).begins_with("ship="):
			continue
		Run.ship_name = (a as String).substr(5).strip_edges()
		print("  flying the %s (a %s)" % [Run.display_name(), Run.hull.name])
		break

	# `-- stationshot full nofaults` clears every malfunction, so the Shipyard's
	# fault post is drawn reading NO FAULTS. `full` always rolls at least one,
	# which left that label reachable by no fixture at all.
	if "nofaults" in OS.get_cmdline_user_args():
		Run.dross = []
		print("  nofaults: %d faults aboard" % Run.dross_count())

	# `-- stationshot full noyard` clears the blocks, so the Shipyard is drawn
	# with nothing for sale. `full` guarantees a hull, which is right for almost
	# every shot and made this path -- your ship and its machines with an empty
	# berth beside them -- unreachable by any fixture.
	if "noyard" in OS.get_cmdline_user_args():
		here.shop_hull = null
		print("  noyard: nothing on the blocks")

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

	# `-- stationshot full deck=hold` photographs a deck other than the one the
	# screen opens on. The rail is a lift and clicking it is the only way in, so
	# without this every shot of this screen was the SERVICES deck and the other
	# four could only be looked at by playing to them.
	#
	#   deck=services  deck=work  deck=stock  deck=hold  deck=bench
	for a in OS.get_cmdline_user_args():
		if not (a as String).begins_with("deck="):
			continue
		var deck := StringName((a as String).substr(5).strip_edges())
		var scr0 := Router.current as StationScreen
		if scr0 == null:
			break
		# NAMED, not indexed. `TABS` is ordered for reading and the rail draws it
		# in a DIFFERENT order again, so a number here would mean neither.
		var known := false
		for row in StationScreen.TABS:
			if row[0] == deck:
				known = true
				break
		if not known:
			print("[station] no deck '%s' -- staying on the one it opened" % deck)
			break
		scr0._show_tab(deck)
		print("  deck: %s" % deck)
		break

	# `-- stationshot full hover` shows the Yard's details slab, which otherwise
	# only appears while a real pointer is over the ship -- and a pushed event
	# never moves the OS cursor.
	if "hover" in OS.get_cmdline_user_args():
		var yard := Router.current as StationScreen
		if yard != null:
			yard._on_ship_hover(true)
			# THE SLAB'S OWN HEIGHT, printed rather than eyeballed.
			#
			# It sat at 293 for 189 of content -- a hundred pixels of nothing
			# under the last perk -- because `set_anchors_and_offsets_preset`
			# writes the CURRENT rect into the offsets and nothing had corrected
			# `offset_bottom` since. A screenshot shows you a panel looks empty;
			# only this says by how much, and against what it should be.
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			if yard._scene_slab != null:
				var need: Vector2 = yard._scene_slab.get_combined_minimum_size()
				print("  slab %.0fx%.0f (min %.0fx%.0f)" % [
					yard._scene_slab.size.x, yard._scene_slab.size.y,
					need.x, need.y])
				if yard._scene_slab.size.y > need.y + 1.0:
					print("    <-- %.0f taller than its content"
						% (yard._scene_slab.size.y - need.y))

	# `-- stationshot full hovermine` shows YOUR ship's slab in the Shipyard,
	# which a pushed event cannot reach any more than it can the other one.
	if "hovermine" in OS.get_cmdline_user_args():
		var yard2 := Router.current as StationScreen
		if yard2 != null:
			yard2._on_mine_hover(true)
			# MEASURED, for the reason the other one is, and the WIDTH as well as
			# the height: with nothing on the blocks this slab has no "AGAINST
			# <SHIP>" in its head row, so it is the narrowest the panel ever has
			# cause to be and the first place spare width shows.
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			if yard2._mine_slab != null:
				var mn: Vector2 = yard2._mine_slab.get_combined_minimum_size()
				print("  mine slab %.0fx%.0f (min %.0fx%.0f)" % [
					yard2._mine_slab.size.x, yard2._mine_slab.size.y,
					mn.x, mn.y])

	# `-- stationshot full purge` opens the fault picker, which is a modal and so
	# unreachable by any flag that only chooses a deck.
	if "purge" in OS.get_cmdline_user_args():
		var scr := Router.current as StationScreen
		if scr != null:
			scr._open_purge()

	# A ROOM SHOT IS OF THE ROOM, NOT OF WHERE THE MOUSE HAPPENS TO BE. The real
	# pointer is wherever it was left on the desk, and over a part on the rack
	# it opens that part's tooltip across the shot.
	for a7 in OS.get_cmdline_user_args():
		if (a7 as String).begins_with("roomshot=") and Router.current != null:
			Router.current.get_viewport().gui_disable_input = true

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

	# `-- stationshot full deck=stock buy` BUYS A PART THE WAY A PLAYER DOES:
	# a real pick-up off the rack, handed to the counter, and the run checked
	# after. The rack is scaled by two and the counter stands where the room
	# puts it, and neither is anything `fittest` reaches. The drop is handed to
	# the counter directly for the reason `FitTest._carry` gives: Godot follows
	# the OS cursor once a drag is live, and warping the real mouse is not a
	# thing a test should do to the machine running it.
	if "buy" in OS.get_cmdline_user_args():
		# ROOM IN THE HOLD. `full` fills it, which is the case the counter
		# rightly refuses ("NO ROOM") -- this is about the purchase, so it
		# makes space the way a player would, by dumping something. First, so
		# the shelf it redraws is the one the part is picked off.
		var scr7 := Router.current as StationScreen
		var icon: ModuleIcon = null
		var pick7: HoldItem = null
		if scr7 != null and scr7._shelf != null:
			for c7 in scr7._shelf.find_children("*", "ModuleIcon", true, false):
				pick7 = (c7 as ModuleIcon).held_item()
				break
		# Room for THIS part: a wide one needs more than a single free cell.
		while pick7 != null and not Run.has_room_for(pick7) and not Run.cargo.is_empty():
			Run.cargo.pop_back()
		Sig.ship_changed.emit()
		for i8 in 6:
			await tree.process_frame
		if scr7 != null and scr7._shelf != null:
			for c8 in scr7._shelf.find_children("*", "ModuleIcon", true, false):
				if (c8 as ModuleIcon).held_item() == pick7:
					icon = c8 as ModuleIcon
					break
		if icon == null or scr7._till == null:
			print("buy: FAIL -- no part on the rack, or no counter")
		else:
			# `Run.stow` puts a part in the hold, or on the pad beside it when no
			# gap in the hold is its shape; either is bought.
			var had := Run.cargo.size() + Run.pad.size()
			var cash := Run.credits
			var part: HoldItem = icon.held_item()
			var target := GameShell.input_target(tree)
			var at := icon.get_global_rect().get_center()
			var mv := InputEventMouseMotion.new()
			mv.position = at
			mv.global_position = at
			target.push_input(mv)
			await tree.process_frame
			var dn := InputEventMouseButton.new()
			dn.button_index = MOUSE_BUTTON_LEFT
			dn.pressed = true
			dn.position = at
			dn.global_position = at
			dn.button_mask = MOUSE_BUTTON_MASK_LEFT
			target.push_input(dn)
			await tree.process_frame
			var mv2 := InputEventMouseMotion.new()
			mv2.position = at + Vector2(10.0, -10.0)
			mv2.global_position = mv2.position
			mv2.relative = Vector2(10.0, -10.0)
			mv2.button_mask = MOUSE_BUTTON_MASK_LEFT
			target.push_input(mv2)
			await tree.process_frame
			var data: Variant = target.gui_get_drag_data()
			var live := target.gui_is_dragging() and typeof(data) == TYPE_DICTIONARY
			var took := false
			if live:
				var local := scr7._till.size * 0.5
				if scr7._till._can_drop_data(local, data):
					scr7._till._drop_data(local, data)
					took = true
			var up := InputEventMouseButton.new()
			up.button_index = MOUSE_BUTTON_LEFT
			up.pressed = false
			up.position = mv2.position
			up.global_position = mv2.position
			target.push_input(up)
			for i7 in 12:
				await tree.process_frame
			var now_have := Run.cargo.size() + Run.pad.size()
			var ok := live and took and now_have == had + 1 and Run.credits < cash \
				and (Run.cargo.has(part) or Run.pad.has(part))
			print("buy: %s -- drag %s, counter %s, carried %d -> %d, credits %d -> %d" % [
				"PASS" if ok else "FAIL", "live" if live else "never started",
				"took it" if took else "refused (%s)" % scr7._till._why, had,
				now_have, cash, Run.credits])

	# `roomshot=<path>`: the shop's room alone, at the game's own 1:1, out of the
	# 960x540 frame -- the picture to put beside the bench's render of the same
	# room. The window shot is the frame scaled to the window through the tube,
	# which is right for judging the game and useless for a pixel diff.
	for a6 in OS.get_cmdline_user_args():
		if not (a6 as String).begins_with("roomshot="):
			continue
		var scr6 := Router.current as StationScreen
		if scr6 == null or scr6._shop == null:
			print("  roomshot: no shop on screen")
			break
		var box := Rect2i(scr6._shop.get_global_rect())
		var frame := scr6._shop.get_viewport().get_texture().get_image()
		var out := frame.get_region(box)
		out.save_png((a6 as String).substr(9))
		print("  roomshot %s: room %s at %s, backdrop %s" % [(a6 as String).substr(9),
			scr6._shop.room.get("slug", "?"), box, scr6._shop._bd_id])
	print("  %s · %s" % ["no berth" if berth == &"none"
		else DB.manufacturer_name(berth) + " berth",
		MapGen.development_name(here.development)])
	var path := "user://station_%s.png" % berth
	tree.root.get_texture().get_image().save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))

	# `layerhz=S`: time every redraw of the station's rooms for S seconds and
	# print how evenly they land. A frame capture a twelfth of a second apart
	# cannot show a 30 Hz layer holding a walker's pose for 83 ms here and 167
	# there -- which is exactly what the walkers did at the old 12 Hz gate.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("layerhz="):
			var secs := float(a.trim_prefix("layerhz="))
			var stamps: Array[int] = []
			var rooms: Array[Node] = tree.root.find_children("*", "StationRoom", true, false)
			var cast_n := 0
			var figures := 0
			for r in rooms:
				print("  room %s: visible %s, views %d, strips %d, walk lines %d, backdrop %s" % [
					r.get_class() if r.get_script() == null else r.name, r.is_visible_in_tree(),
					r._views.size(), r._strips.size(), r._walk_lines.size(), r._backdrop])
				(r as CanvasItem).draw.connect(func(): stamps.append(Time.get_ticks_usec()))
				for w in r._cast:
					cast_n += 1
					if bool(w.get("figure", false)):
						figures += 1
			var until := Time.get_ticks_msec() + int(secs * 1000.0)
			var fps_sum := 0.0
			var fps_n := 0
			while Time.get_ticks_msec() < until:
				await RenderingServer.frame_post_draw
				fps_sum += Engine.get_frames_per_second()
				fps_n += 1
			var gaps := {}
			for i in range(1, stamps.size()):
				var g := roundi(float(stamps[i] - stamps[i - 1]) / 1000.0)
				if g > 0:
					gaps[g] = int(gaps.get(g, 0)) + 1
			var keys := gaps.keys()
			keys.sort()
			var hist := PackedStringArray()
			for k in keys:
				hist.append("%dms x%d" % [k, gaps[k]])
			print("  layer: %d room(s), %d in the cast (%d drawn figures), %.1f redraws/s, %.0f fps" % [
				rooms.size(), cast_n, figures, float(stamps.size()) / secs,
				fps_sum / maxf(1.0, float(fps_n))])
			print("  layer gaps: ", ", ".join(hist))

	# `frames=N`: N more shots a twelfth of a second apart, for the layers that
	# move. A still cannot show that a walker walks or that the near lane is
	# faster than the far one, and those are the whole point of them.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("frames="):
			var n := int(a.trim_prefix("frames="))
			for f in n:
				var until := Time.get_ticks_msec() + 83
				while Time.get_ticks_msec() < until:
					await RenderingServer.frame_post_draw
				var fp := "user://station_%s_f%02d.png" % [berth, f]
				tree.root.get_texture().get_image().save_png(fp)
			print("wrote %d frames" % n)
	tree.quit()
