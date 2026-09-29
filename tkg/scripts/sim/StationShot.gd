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
		elif s3.begins_with("labshots="):
			# The lab's now-and-then sounds this far apart, for a test: `labshots=4,6`.
			var ab := s3.substr(9).split(",")
			LabScene.shot_every = Vector2(float(ab[0]), float(ab[1]))
		elif s3.begins_with("labclock="):
			# The Laboratory held this many seconds after it powered on: `6`
			# is settled, under three is the power-on itself.
			LabScene.pin_clock = float(s3.substr(9))
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

	# `-- stationshot full deck=hold hold=6x5` gives the ship a hold of another
	# size, so the Exchange stands that hull's frame. The test ship's is 5x4,
	# which photographed the medium frame only, and every room is laid out round
	# three. What no longer fits goes on the pad, as a hull swap puts it.
	for a in OS.get_cmdline_user_args():
		if not (a as String).begins_with("hold="):
			continue
		var wh := (a as String).substr(5).split("x")
		Run.hull.hold_grid = Vector2i(int(wh[0]), int(wh[1]))
		Run.repack_hold()
		print("  hold: %dx%d, %d aboard, %d on the pad" % [Run.hold_grid().x,
			Run.hold_grid().y, Run.cargo.size(), Run.pad.size()])
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
		# A LAB BELOW A CITY HAS NO RECIPE YET (`Fabricator.available`), so its
		# deck is closed -- and the lab is Jon's picture all the same. The shot
		# opens it anyway, empty, so every level's lab can be looked at.
		if deck == &"bench" and not scr0._tabs_on.get(&"bench", true):
			scr0._enable_tab(&"bench", true)
			print("  deck: bench has no recipe at this level -- opened for the shot")
		scr0._show_tab(deck)
		print("  deck: %s" % deck)
		break

	# `labtape=<path>`: the Laboratory's power-on as the game plays it, heard rather
	# than seen -- every sound Audio really plays in the 4.5 s after the lab powers
	# on, as [name, seconds after power-on], written to <path> as json. The lab's
	# clock has to run for it (no labclock=); what it hears is POWER_ON_SOUNDS
	# through Audio.play, rate limits and all. Needs a window: without one Audio
	# is off and the tape stays empty.
	for a12 in OS.get_cmdline_user_args():
		if not (a12 as String).begins_with("labtape="):
			continue
		var scr12 := Router.current as StationScreen
		if scr12 == null or scr12._lab == null or not scr12._lab.is_visible_in_tree():
			print("  labtape: no lab on screen")
			break
		var lab12 := scr12._lab
		Audio.tape.clear()
		Audio.taping = true
		# `labtapes=S` records S seconds, for the ambience after the power-on.
		var secs12 := 4.5
		for b12 in OS.get_cmdline_user_args():
			if (b12 as String).begins_with("labtapes="):
				secs12 = float((b12 as String).substr(9))
		await tree.create_timer(secs12).timeout
		Audio.taping = false
		# When the lab powered on, in the tape's milliseconds: its clock has run
		# in real time since, so that far back from now.
		var boot12 := float(Time.get_ticks_msec()) - (lab12._lab_clock - lab12._boot_at) * 1000.0
		var heard12 := []
		for e12 in Audio.tape:
			heard12.append([String(e12[0]), snappedf((float(e12[1]) - boot12) / 1000.0, 0.001), float(e12[2]), float(e12[3])])
		var f12 := FileAccess.open((a12 as String).substr(8), FileAccess.WRITE)
		f12.store_string(JSON.stringify({"lab": lab12._level, "heard": heard12}))
		f12.close()
		print("  labtape %s: lab %s, %d sounds" % [(a12 as String).substr(8), lab12._level, heard12.size()])
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

	# `-- stationshot full deck=hold flyby` holds the Exchange's clock at the
	# first moment a ship is crossing the window its world is framed in, so a
	# pass can be photographed on purpose rather than waited for. `flyby=N`
	# takes the Nth such moment instead.
	for a10 in OS.get_cmdline_user_args():
		if not ((a10 as String) == "flyby" or (a10 as String).begins_with("flyby=")):
			continue
		var want10 := int((a10 as String).substr(6)) if (a10 as String).begins_with("flyby=") else 1
		var scr10 := Router.current as StationScreen
		if scr10 == null or scr10._exchange == null:
			print("  flyby: no Exchange on screen")
			break
		var ex10: ExchangeScene = scr10._exchange
		var fr10: Variant = ex10.room.get("sky_frame", null)
		if not (fr10 is Array):
			print("  flyby: this room frames no window")
			break
		var win10 := Rect2(float(fr10[0]), float(fr10[1]), float(fr10[2]), float(fr10[3]))
		var seen10 := 0
		var was_in := false
		for step10 in 2400:
			ex10._clock = float(step10) * 0.25
			ex10._pose_cast()
			var now_in := false
			for p10 in ex10._posed:
				var r10 := Rect2(p10[1], Vector2((p10[0] as Texture2D).get_size()))
				if win10.encloses(r10):
					now_in = true
			if now_in and not was_in:
				seen10 += 1
				if seen10 == want10:
					ShopScene.pin_clock_ms = ex10._clock * 1000.0
					print("  flyby: pass %d in the window at %.2fs" % [seen10, ex10._clock])
					break
			was_in = now_in
		if seen10 < want10:
			print("  flyby: only %d passes through the window in ten minutes" % seen10)
		break

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

	# `-- stationshot full deck=hold sell` SELLS A PART THE WAY A PLAYER DOES: a
	# real pick-up out of the hold, which stands in the Exchange's frame, handed
	# to the counter that pays, and the run checked after. The same drag the buy
	# test makes, the other way across the room.
	if "sell" in OS.get_cmdline_user_args():
		var scr8 := Router.current as StationScreen
		var icon8: Control = null
		var part8: HoldItem = null
		if scr8 != null and scr8._hold_grid != null:
			for c9 in scr8._hold_grid.get_children():
				if not c9.has_method("held_item"):
					continue
				var m9: HoldItem = c9.held_item()
				if m9 != null and TradeCounter.refusal(TradeCounter.Side.PAYS, m9) == "":
					icon8 = c9 as Control
					part8 = m9
					break
		if icon8 == null or scr8._sell_desk == null:
			print("sell: FAIL -- nothing in the hold the counter will take, or no counter")
		else:
			var had8 := Run.cargo.size()
			var cash8 := Run.credits
			var target8 := GameShell.input_target(tree)
			var at8 := icon8.get_global_rect().get_center()
			var mv8 := InputEventMouseMotion.new()
			mv8.position = at8
			mv8.global_position = at8
			target8.push_input(mv8)
			await tree.process_frame
			var dn8 := InputEventMouseButton.new()
			dn8.button_index = MOUSE_BUTTON_LEFT
			dn8.pressed = true
			dn8.position = at8
			dn8.global_position = at8
			dn8.button_mask = MOUSE_BUTTON_MASK_LEFT
			target8.push_input(dn8)
			await tree.process_frame
			var mv9 := InputEventMouseMotion.new()
			mv9.position = at8 + Vector2(10.0, -10.0)
			mv9.global_position = mv9.position
			mv9.relative = Vector2(10.0, -10.0)
			mv9.button_mask = MOUSE_BUTTON_MASK_LEFT
			target8.push_input(mv9)
			await tree.process_frame
			var data8: Variant = target8.gui_get_drag_data()
			var live8 := target8.gui_is_dragging() and typeof(data8) == TYPE_DICTIONARY
			var took8 := false
			if live8:
				var local8 := scr8._sell_desk.size * 0.5
				if scr8._sell_desk._can_drop_data(local8, data8):
					scr8._sell_desk._drop_data(local8, data8)
					took8 = true
			var up8 := InputEventMouseButton.new()
			up8.button_index = MOUSE_BUTTON_LEFT
			up8.pressed = false
			up8.position = mv9.position
			up8.global_position = mv9.position
			target8.push_input(up8)
			for i9 in 12:
				await tree.process_frame
			var ok8 := live8 and took8 and Run.cargo.size() == had8 - 1 \
				and not Run.cargo.has(part8) and Run.credits > cash8
			print("sell: %s -- drag %s, counter %s, hold %d -> %d, credits %d -> %d" % [
				"PASS" if ok8 else "FAIL", "live" if live8 else "never started",
				"took it" if took8 else "refused (%s)" % scr8._sell_desk._why, had8,
				Run.cargo.size(), cash8, Run.credits])

	# `skyview=<path>`: THIS STATION'S SKY at backdrop size, 800x400 -- the
	# planet it orbits and its stars, as the sector draws them -- for the
	# Exchange's bench to hang behind its windows. `skyseed=N` borrows node
	# index N for the roll, so five levels can show five different skies
	# without moving the station anywhere. `skyseed=3,9,14` rolls several in one
	# run, each to the path with `{seed}` replaced; `skysize=740x431` draws the
	# sky at the size of the room's wall, the way the Exchange hangs it, and
	# `skyframe=x,y,w,h` frames its world in that rect of it, as the Exchange
	# frames it in the room's biggest window. `skyparts` also writes the sky
	# without its world (`<path>` with `_stars` before `.png`) and the world
	# alone at the size it is drawn (`_body`), for the bench to frame live.
	for a9 in OS.get_cmdline_user_args():
		if not (a9 as String).begins_with("skyview="):
			continue
		var node9: MapGen.MapNode = Run.node_at()
		var was_index := node9.index
		var seeds9: Array = [was_index]
		var size9 := Vector2i(800, 400)
		var frame9 := Rect2()
		for a10 in OS.get_cmdline_user_args():
			if (a10 as String).begins_with("skyseed="):
				seeds9 = Array((a10 as String).substr(8).split(",")).map(func(v): return int(v))
			if (a10 as String).begins_with("skysize="):
				var wh9 := (a10 as String).substr(8).split("x")
				size9 = Vector2i(int(wh9[0]), int(wh9[1]))
			if (a10 as String).begins_with("skyframe="):
				var fr9 := (a10 as String).substr(9).split(",")
				frame9 = Rect2(float(fr9[0]), float(fr9[1]), float(fr9[2]), float(fr9[3]))
		for seed9 in seeds9:
			node9.index = seed9
			var vp := SubViewport.new()
			vp.size = size9
			vp.transparent_bg = false
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			var sky := SpaceBackdrop.new()
			sky.size = Vector2(size9)
			sky.frame_in = frame9
			vp.add_child(sky)
			tree.root.add_child(vp)
			sky.setup(node9)
			for i9 in 6:
				await RenderingServer.frame_post_draw
			var path9 := (a9 as String).substr(8).replace("{seed}", str(seed9))
			vp.get_texture().get_image().save_png(path9)
			print("  skyview %s (index %d)" % [path9, seed9])
			if "skyparts" in OS.get_cmdline_user_args() and sky._body != null:
				var body9: Image = sky._body.get_image()
				body9.resize(body9.get_width() * sky._body_px, body9.get_height() * sky._body_px,
					Image.INTERPOLATE_NEAREST)
				body9.save_png(path9.replace(".png", "_body.png"))
				sky._body = null
				sky.queue_redraw()
				vp.render_target_update_mode = SubViewport.UPDATE_ONCE
				for i10 in 4:
					await RenderingServer.frame_post_draw
				vp.get_texture().get_image().save_png(path9.replace(".png", "_stars.png"))
				print("  skyparts: body %dx%d at %.4f,%.4f of the view, disc top %d, radius %d" % [
					body9.get_width(), body9.get_height(), sky._body_at.x, sky._body_at.y,
					int(sky._disc_top), int(sky._disc_r)])
			vp.queue_free()
		node9.index = was_index
		break

	# `roomshot=<path>`: the shop's room alone, at the game's own 1:1, out of the
	# 960x540 frame -- the picture to put beside the bench's render of the same
	# room. The window shot is the frame scaled to the window through the tube,
	# which is right for judging the game and useless for a pixel diff.
	for a6 in OS.get_cmdline_user_args():
		if not (a6 as String).begins_with("roomshot="):
			continue
		var scr6 := Router.current as StationScreen
		# THE LABORATORY is a picture, not a room: its 740x431 from its top-left.
		if scr6 != null and scr6._lab != null and scr6._lab.is_visible_in_tree():
			var lb := Rect2i(Vector2i(scr6._lab.get_global_rect().position), Vector2i(LabScene.PANEL))
			var lframe := scr6._lab.get_viewport().get_texture().get_image()
			lframe.get_region(lb).save_png((a6 as String).substr(9))
			print("  roomshot %s: lab %s at %s" % [(a6 as String).substr(9), scr6._lab._level, lb])
			break
		# THE ROOM ON SCREEN: the Exchange's when that deck is up, else the shop's.
		var room6: ShopScene = null
		if scr6 != null:
			room6 = scr6._shop
			if scr6._exchange != null and scr6._exchange.is_visible_in_tree():
				room6 = scr6._exchange
		if room6 == null:
			print("  roomshot: no room on screen")
			break
		var box := Rect2i(room6.get_global_rect())
		var frame := room6.get_viewport().get_texture().get_image()
		var out := frame.get_region(box)
		out.save_png((a6 as String).substr(9))
		print("  roomshot %s: room %s at %s, backdrop %s" % [(a6 as String).substr(9),
			room6.room.get("slug", "?"), box, room6._bd_id])
	# `roomclip=<dir>`: the room on screen as a run of frames, `clipframes=N`
	# of them (90) `clipms=M` apart (66, fifteen a second), starting `clipfrom=`
	# milliseconds before the clock the shot was held at (2000) -- a pass by a
	# window, to be judged moving. Speed can only be judged in motion.
	for a11 in OS.get_cmdline_user_args():
		if not (a11 as String).begins_with("roomclip="):
			continue
		var scr11 := Router.current as StationScreen
		var room11: ShopScene = null
		if scr11 != null:
			room11 = scr11._shop
			if scr11._exchange != null and scr11._exchange.is_visible_in_tree():
				room11 = scr11._exchange
		if room11 == null:
			print("  roomclip: no room on screen")
			break
		var frames11 := 90
		var step11 := 66.0
		var back11 := 2000.0
		for b11 in OS.get_cmdline_user_args():
			if (b11 as String).begins_with("clipframes="):
				frames11 = int((b11 as String).substr(11))
			elif (b11 as String).begins_with("clipms="):
				step11 = float((b11 as String).substr(7))
			elif (b11 as String).begins_with("clipfrom="):
				back11 = float((b11 as String).substr(9))
		var t11 := maxf(0.0, ShopScene.pin_clock_ms - back11) if ShopScene.pin_clock_ms >= 0.0 else 0.0
		var dir11 := (a11 as String).substr(9)
		DirAccess.make_dir_recursive_absolute(dir11)
		var box11 := Rect2i(room11.get_global_rect())
		for i11 in frames11:
			ShopScene.pin_clock_ms = t11 + float(i11) * step11
			room11.queue_redraw()
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img11 := room11.get_viewport().get_texture().get_image().get_region(box11)
			img11.save_png("%s/frame_%03d.png" % [dir11, i11])
		print("  roomclip: %d frames from %.2fs to %s" % [frames11, t11 / 1000.0, dir11])
		break

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
