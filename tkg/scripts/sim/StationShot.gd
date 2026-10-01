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
		elif s3 == "roomview":
			# The room's backdrop and its walkers alone, no room round them.
			StationRoom.view_only = true
		elif s3.begins_with("backdrop="):
			StationRoom.forced_views[&"backdrop"] = StringName(s3.substr(9))
		elif s3.begins_with("yardclock="):
			# The Shipyard held this many seconds after its TV powered on: under
			# four is the power-on and the drones flying in, six is settled.
			YardScene.pin_clock = float(s3.substr(10))
		elif s3.begins_with("yardev="):
			# Rare events fired at seconds after power-on: `yardev=E11:1,E14:3.5`.
			for ev in s3.substr(7).split(","):
				var kv := ev.split(":")
				YardScene.fire_at.append([kv[0], float(kv[1]) if kv.size() > 1 else 0.0])
		elif s3 == "yard=bare":
			# The hall and the ships alone, lit: set against the page's own.
			YardScene.bare = true
		elif s3 == "yard=painted":
			# The yard as painted, no light: set against Jon's pictures.
			YardScene.fullbright = true

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

	# `fit=full`: every hardpoint the hull has, filled with its own manufacturer's
	# parts, to see how a fitted hull reads -- `manufacturer=korvan` for the
	# manufacturer whose parts are all drawn. `fit=full:heavy:3` refits the
	# chassis first, at that weight and grade. Couplings go on first, since a
	# part that raises the reactor makes room for the rest; then the smallest
	# draw, different parts before repeats, and only what the reactor will run:
	# a ship a player could fly.
	for a8 in OS.get_cmdline_user_args():
		if not (a8 as String).begins_with("fit=full"):
			continue
		var fw := (a8 as String).split(":")
		if fw.size() > 1:
			var weights8 := {"light": HullData.Weight.LIGHT, "medium": HullData.Weight.MEDIUM, "heavy": HullData.Weight.HEAVY}
			Run.fit_chassis(Run.hull.manufacturer, weights8.get(fw[1], HullData.Weight.MEDIUM),
				int(fw[2]) if fw.size() > 2 else 0)
		var own: Array[ModuleData] = []
		for mid8 in DB.modules:
			var m8: ModuleData = DB.modules[mid8]
			if m8.manufacturer == Run.hull.manufacturer:
				own.append(m8)
		own.sort_custom(func(x: ModuleData, y: ModuleData) -> bool:
			if x.reactor != y.reactor:
				return x.reactor > y.reactor
			return x.cells() < y.cells())
		for pass8 in 2:
			for m9: ModuleData in own:
				if pass8 == 0 and Run.installed.any(func(on: ModuleData) -> bool: return on.id == m9.id):
					continue
				if Run.slots_used(m9.slot) < Run.slots_for(m9.slot) and Run.can_power(m9):
					Run.install_module(m9.duplicate(true) as ModuleData)
		var mounts8 := 0
		for s8: ModuleData.Slot in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]:
			mounts8 += Run.slots_for(s8)
		print("  fit=full: %s, %d of %d mounts fitted, drawing %d" % [Run.hull.name, Run.installed.size(), mounts8, Run.power_draw()])
		break

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
		# `yardhull=medium:2`: a Korvan frame of that weight at that grade on the
		# blocks -- the Yard Drones page stood a grade-A medium there.
		for ah in OS.get_cmdline_user_args():
			if (ah as String).begins_with("yardhull="):
				var wt := (ah as String).substr(9).split(":")
				var weights := {"light": HullData.Weight.LIGHT, "medium": HullData.Weight.MEDIUM, "heavy": HullData.Weight.HEAVY}
				here.shop_hull = DB.at_tier(DB.hull_for(&"korvan", weights.get(wt[0], HullData.Weight.MEDIUM)), int(wt[1]) if wt.size() > 1 else 2)
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
	# `hullfull` docks with the hull whole, so PATCH and REPAIR have nothing to
	# sell and their drones stay away (`YardDrones._stay_away`).
	if "hullfull" in OS.get_cmdline_user_args():
		Run.hp = Run.max_hp()
		print("  hullfull: hull %d of %d" % [Run.hp, Run.max_hp()])

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
		# the dock opens over the station, as it does in play
		Router.show_station()
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

	# `revisit`: A DECK POWERS ON ONCE A DOCKING. Let the deck power on, go to the
	# star chart and back the way the HUD does, open the same deck again, and
	# print whether it came back settled (already on, nothing replayed) or powered
	# on a second time. Then undock and dock, where it must power on afresh
	# (`revisit=chart` stops after the chart, to photograph the deck come back).
	var cmd := OS.get_cmdline_user_args()
	if cmd.has("revisit") or cmd.has("revisit=chart"):
		var scr1 := Router.current as StationScreen
		var deck1: StringName = scr1._tab if scr1 != null else &""
		await tree.create_timer(1.5).timeout
		var legs := ["chart and back"] if cmd.has("revisit=chart") else ["chart and back", "undock and dock"]
		for leg: String in legs:
			if leg == "chart and back":
				Router.show_starchart()
			else:
				Router.show_sector()
			await tree.create_timer(0.5).timeout
			Router.show_station()
			await tree.process_frame
			var scr2 := Router.current as StationScreen
			if scr2 == null:
				print("  revisit: no station after %s" % leg)
				break
			if deck1 == &"bench" and not scr2._tabs_on.get(&"bench", true):
				scr2._enable_tab(&"bench", true)
			scr2._show_tab(deck1)
			await tree.create_timer(0.5).timeout
			var settled := false
			if deck1 == &"bench" and scr2._lab != null:
				settled = scr2._lab._boot_heard
			elif deck1 == &"services" and scr2._scene != null:
				settled = scr2._scene._clock - scr2._scene._tp >= YardScene.SETTLED
			elif deck1 == &"work" and scr2._board_lamp != null:
				settled = scr2._board_lamp._settled and scr2._board_lamp._now() - scr2._board_lamp._boot_at > 5.0
			print("  revisit: %s after %s -- %s" % [deck1, leg, "settled, not powered on again" if settled else "powered on again"])

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

	# `boardav=<dir>`: the Hiring Board seen AND heard, as a player gets it: the
	# station picked by `avseed=N`, powered on from dark, for `avsecs=S` (24)
	# seconds -- every frame of the board, with when it was drawn
	# (`frames.json`), and everything the game played on its master bus
	# (`audio.wav`), music and station included. On a screen, a popup is
	# clicked shut 2.5 s after it opens, as a player would. Needs a window.
	for a23 in OS.get_cmdline_user_args():
		if not (a23 as String).begins_with("boardav="):
			continue
		var scr23 := Router.current as StationScreen
		if scr23 == null or scr23._board_lamp == null or not scr23._board_lamp.is_visible_in_tree():
			print("  boardav: no board on screen")
			break
		var bd23 := scr23._board
		var lamp23 := scr23._board_lamp
		var dir23 := (a23 as String).substr(8)
		DirAccess.make_dir_recursive_absolute(dir23)
		var secs23 := 24.0
		for b23 in OS.get_cmdline_user_args():
			if (b23 as String).begins_with("avsecs="):
				secs23 = float((b23 as String).substr(7))
			elif (b23 as String).begins_with("avseed="):
				bd23.station_seed = int((b23 as String).substr(7))
		await tree.process_frame
		# A CAPTURE, NOT A RECORD: AudioEffectRecord hands back silence here (4.7,
		# WASAPI, added at run time) though the master bus meters -6 dB. The
		# capture's ring buffer is drained every frame instead, into `pcm23`.
		var cap23 := AudioEffectCapture.new()
		cap23.buffer_length = 2.0
		AudioServer.add_bus_effect(0, cap23)
		await tree.create_timer(0.3).timeout
		cap23.clear_buffer()
		var pcm23 := PackedVector2Array()
		var t23 := Time.get_ticks_msec()
		lamp23.power_on(false)
		bd23._pop_at = -1.0
		bd23._pop_next = PostingBoard._t() + PostingBoard.POP_FIRST
		var times23 := []
		var clicked23 := false
		var i23 := 0
		while float(Time.get_ticks_msec() - t23) / 1000.0 < secs23:
			await RenderingServer.frame_post_draw
			var box23 := Rect2i(lamp23.get_global_rect())
			lamp23.get_viewport().get_texture().get_image().get_region(box23).save_png("%s/frame_%04d.png" % [dir23, i23])
			times23.append(float(Time.get_ticks_msec() - t23) / 1000.0)
			pcm23.append_array(cap23.get_buffer(cap23.get_frames_available()))
			if i23 % 20 == 0 and "avmeter" in OS.get_cmdline_user_args():
				var playing23 := 0
				for p23 in Audio._sfx:
					if (p23 as AudioStreamPlayer).playing:
						playing23 += 1
				print("  boardav meter %.2fs: master %.1f dB, %d sfx playing" % [times23[-1], AudioServer.get_bus_peak_volume_left_db(0, 0), playing23])
			i23 += 1
			if not clicked23 and bd23._pop_at >= 0.0 and PostingBoard._t() - bd23._pop_at > 2.5 and bd23.pop_x.has_area():
				clicked23 = true
				var at23 := bd23.get_global_transform() * bd23.pop_x.get_center()
				var target23 := GameShell.input_target(tree)
				for pressed in [true, false]:
					var mb23 := InputEventMouseButton.new()
					mb23.button_index = MOUSE_BUTTON_LEFT
					mb23.pressed = pressed
					mb23.position = at23
					mb23.global_position = at23
					target23.push_input(mb23)
		pcm23.append_array(cap23.get_buffer(cap23.get_frames_available()))
		AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
		# ONE BLOCK PER SPEAKER PAIR: on a 7.1 output the master bus is four stereo
		# pairs, and the capture is handed each pair's 512-frame mix block in turn
		# (front, centre, rear, side). The front pair is what plays on stereo; keep
		# it, drop the rest, or the sound runs four times too long.
		var pairs23 := int(AudioServer.get_speaker_mode()) + 1
		if pairs23 > 1:
			var front23 := PackedVector2Array()
			var blk23 := 512
			var at23b := 0
			while at23b < pcm23.size():
				front23.append_array(pcm23.slice(at23b, mini(at23b + blk23, pcm23.size())))
				at23b += blk23 * pairs23
			pcm23 = front23
		# 16-bit stereo PCM at the mix rate, as a plain RIFF wav
		var rate23 := int(AudioServer.get_mix_rate())
		var data23 := PackedByteArray()
		data23.resize(pcm23.size() * 4)
		for k23 in pcm23.size():
			data23.encode_s16(k23 * 4, int(clampf(pcm23[k23].x, -1.0, 1.0) * 32767.0))
			data23.encode_s16(k23 * 4 + 2, int(clampf(pcm23[k23].y, -1.0, 1.0) * 32767.0))
		var w23 := FileAccess.open("%s/audio.wav" % dir23, FileAccess.WRITE)
		w23.store_buffer("RIFF".to_ascii_buffer())
		w23.store_32(36 + data23.size())
		w23.store_buffer("WAVEfmt ".to_ascii_buffer())
		w23.store_32(16)
		w23.store_16(1)
		w23.store_16(2)
		w23.store_32(rate23)
		w23.store_32(rate23 * 4)
		w23.store_16(4)
		w23.store_16(16)
		w23.store_buffer("data".to_ascii_buffer())
		w23.store_32(data23.size())
		w23.store_buffer(data23)
		w23.close()
		var f23 := FileAccess.open("%s/frames.json" % dir23, FileAccess.WRITE)
		f23.store_string(JSON.stringify(times23))
		f23.close()
		print("  boardav: dev %d seed %d, %d frames over %.1f s, %.1f s of sound at %d Hz" % [lamp23.dev, bd23.station_seed, i23,
			times23[-1] if not times23.is_empty() else 0.0, float(pcm23.size()) / float(rate23), rate23])
		break

	# `boardtape=<path>`: the Hiring Board heard -- every sound the game plays for
	# `boardtapes=S` seconds (12) after its lights power on, as [name, seconds
	# after power-on]: the tubes striking, their flickers, a screen's power-on,
	# popups and commercials. Needs a window.
	for a22 in OS.get_cmdline_user_args():
		if not (a22 as String).begins_with("boardtape="):
			continue
		var scr22 := Router.current as StationScreen
		if scr22 == null or scr22._board_lamp == null or not scr22._board_lamp.is_visible_in_tree():
			print("  boardtape: no board on screen")
			break
		var lamp22 := scr22._board_lamp
		Audio.tape.clear()
		Audio.taping = true
		var secs22 := 12.0
		for b22 in OS.get_cmdline_user_args():
			if (b22 as String).begins_with("boardtapes="):
				secs22 = float((b22 as String).substr(11))
		await tree.create_timer(secs22).timeout
		Audio.taping = false
		var boot22 := lamp22._boot_at * 1000.0
		var heard22 := []
		for e22 in Audio.tape:
			heard22.append([String(e22[0]), snappedf((float(e22[1]) - boot22) / 1000.0, 0.001)])
		var f22 := FileAccess.open((a22 as String).substr(10), FileAccess.WRITE)
		f22.store_string(JSON.stringify({"dev": lamp22.dev, "heard": heard22}))
		f22.close()
		print("  boardtape: dev %d, %s" % [lamp22.dev, heard22])
		break

	# `yardtape=<path>`: the Shipyard heard -- every sound the game plays for
	# `yardtapes=S` seconds (12) after its TV powers on, as [name, seconds after
	# power-on], on the yard's own running clock (no `yardclock=`). The TV's
	# power-on, the bed, the drones flying in and at work (`yardbuy=I:S` buys as
	# a click does), the welder, the now-and-then, a light's flicker. Needs a
	# window: without one there is no sound.
	for a14 in OS.get_cmdline_user_args():
		if not (a14 as String).begins_with("yardtape="):
			continue
		var scr14 := Router.current as StationScreen
		if scr14 == null or scr14._scene == null or not scr14._scene.is_visible_in_tree():
			print("  yardtape: no yard on screen")
			break
		var yard14 := scr14._scene
		var secs14 := 12.0
		var buys14: Array = []
		for b14 in OS.get_cmdline_user_args():
			if (b14 as String).begins_with("yardtapes="):
				secs14 = float((b14 as String).substr(10))
			elif (b14 as String).begins_with("yardbuy="):
				for pair in (b14 as String).substr(8).split(","):
					var kv14 := pair.split(":")
					buys14.append([int(kv14[0]), float(kv14[1]), false])
		Audio.tape.clear()
		Audio.taping = true
		var boot14 := float(Time.get_ticks_msec()) - (yard14._clock - yard14._tp) * 1000.0
		while (float(Time.get_ticks_msec()) - boot14) / 1000.0 < secs14:
			var now14 := (float(Time.get_ticks_msec()) - boot14) / 1000.0
			for bb14: Array in buys14:
				if not bb14[2] and now14 >= float(bb14[1]):
					bb14[2] = true
					scr14._on_yard_service(int(bb14[0]))
			await RenderingServer.frame_post_draw
		Audio.taping = false
		var heard14 := []
		for e14 in Audio.tape:
			heard14.append([String(e14[0]), snappedf((float(e14[1]) - boot14) / 1000.0, 0.001)])
		var f14 := FileAccess.open((a14 as String).substr(9), FileAccess.WRITE)
		f14.store_string(JSON.stringify({"yard": yard14.level, "heard": heard14}))
		f14.close()
		print("  yardtape %s: yard %s, %d sounds" % [(a14 as String).substr(9), yard14.level, heard14.size()])
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
		# THE SHIPYARD is a picture too: its 766x482 from its top-left.
		if scr6 != null and scr6._scene != null and scr6._scene.is_visible_in_tree():
			var yb := Rect2i(Vector2i(scr6._scene.get_global_rect().position), Vector2i(YardScene.W, YardScene.H))
			var yframe := scr6._scene.get_viewport().get_texture().get_image()
			yframe.get_region(yb).save_png((a6 as String).substr(9))
			# and where each stand stands, its picture's left edge, to crop by
			var xs6: Array = []
			for P6: Dictionary in scr6._scene.placed:
				for s6: Dictionary in P6.get("supports", []):
					xs6.append(int(s6["x"]))
			print("  roomshot %s: yard %s at %s, stands at %s" % [(a6 as String).substr(9), scr6._scene.level, yb, xs6])
			break
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
		if StationRoom.view_only:
			# `roomview`: nothing of the room over its backdrop, so what is
			# filmed is the place outside and the people walking it.
			for c11 in room11.get_children() + room11.get_parent().get_children():
				if c11 is CanvasItem and c11 != room11:
					(c11 as CanvasItem).visible = false
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

	# `boardpop`: on a city's or a capital's screen, wait for a popup, click its
	# X as a player does, and print whether it shut.
	# `boardpopbtn` clicks the popup's own button instead, which shuts it too.
	var btn17 := "boardpopbtn" in OS.get_cmdline_user_args()
	if "boardpop" in OS.get_cmdline_user_args() or btn17:
		var scr17 := Router.current as StationScreen
		var bd17: PostingBoard = scr17._board if scr17 != null else null
		if bd17 == null or not bd17.screen():
			print("  boardpop: no screen on this board")
		else:
			var waited := 0.0
			while not bd17.pop_x.has_area() and waited < 25.0:
				await tree.create_timer(0.1).timeout
				waited += 0.1
			if not bd17.pop_x.has_area():
				print("  boardpop: no popup came")
			else:
				# it stays up until it is shut: wait a while, then look
				await tree.create_timer(6.0).timeout
				print("  boardpop: after 6s untouched it is %s" % ["still up" if bd17.pop_x.has_area() else "GONE"])
				var at17 := bd17.get_global_transform() * (bd17.pop_btn if btn17 else bd17.pop_x).get_center()
				var target17 := GameShell.input_target(tree)
				for pressed in [true, false]:
					var mb17 := InputEventMouseButton.new()
					mb17.button_index = MOUSE_BUTTON_LEFT
					mb17.pressed = pressed
					mb17.position = at17
					mb17.global_position = at17
					target17.push_input(mb17)
					await tree.process_frame
				await tree.process_frame
				print("  boardpop: popup opened after %.1fs; after a click on its %s it is %s" % [waited, "button" if btn17 else "X",
					"shut" if not bd17.pop_x.has_area() else "STILL OPEN"])

	# `boardclip=<dir>`: the Hiring Board as the game shows it -- the board, its
	# notices and its lamp -- a frame every `clipms=M` (33) for `clipframes=N`
	# (90) on the real clock its lamp keeps, from the moment the deck opened, so
	# the power-on is in it.
	for a16 in OS.get_cmdline_user_args():
		if not (a16 as String).begins_with("boardclip="):
			continue
		var scr16 := Router.current as StationScreen
		if scr16 == null or scr16._board_lamp == null or not scr16._board_lamp.is_visible_in_tree():
			print("  boardclip: no board on screen")
			break
		var frames16 := 90
		var step16 := 33.0
		for b16 in OS.get_cmdline_user_args():
			if (b16 as String).begins_with("clipframes="):
				frames16 = int((b16 as String).substr(11))
			elif (b16 as String).begins_with("clipms="):
				step16 = float((b16 as String).substr(7))
		var dir16 := (a16 as String).substr(10)
		DirAccess.make_dir_recursive_absolute(dir16)
		var lamp16 := scr16._board_lamp
		var box16 := Rect2i(lamp16.get_global_rect())
		for i16 in frames16:
			await tree.create_timer(step16 / 1000.0).timeout
			await RenderingServer.frame_post_draw
			var img16 := lamp16.get_viewport().get_texture().get_image().get_region(box16)
			img16.save_png("%s/frame_%03d.png" % [dir16, i16])
		print("  boardclip: %d frames of %s to %s" % [frames16, box16, dir16])
		break

	# `boardtab=<i>`: on a screen, click tab i (0 ALL, 1 HAULAGE, 2 BOUNTY, 3 HEAT)
	# as a player does, and print each tab's count and how many notices show.
	for a20 in OS.get_cmdline_user_args():
		if not (a20 as String).begins_with("boardtab="):
			continue
		var scr20 := Router.current as StationScreen
		var bd20: PostingBoard = scr20._board if scr20 != null else null
		if bd20 == null or not bd20.screen():
			print("  boardtab: no screen on this board")
			break
		await tree.process_frame
		await RenderingServer.frame_post_draw
		var i20 := int((a20 as String).substr(9))
		print("  boardtab: counts %s, %d notices before" % [bd20.tab_counts, scr20._work.get_child_count()])
		var at20 := bd20.get_global_transform() * bd20._tab_rects[i20].get_center()
		var target20 := GameShell.input_target(tree)
		for pressed in [true, false]:
			var mb20 := InputEventMouseButton.new()
			mb20.button_index = MOUSE_BUTTON_LEFT
			mb20.pressed = pressed
			mb20.position = at20
			mb20.global_position = at20
			target20.push_input(mb20)
			await tree.process_frame
		await tree.process_frame
		print("  boardtab: picked %s, tab is %d, %d notices after" % [PostingBoard.TABS[i20], bd20.tab, scr20._work.get_child_count()])
		# `tabshot=<png>`: and photograph the board after
		for b20 in OS.get_cmdline_user_args():
			if (b20 as String).begins_with("tabshot="):
				scr20._board_lamp.power_on(true)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var box20 := Rect2i(scr20._board_lamp.get_global_rect())
				scr20._board_lamp.get_viewport().get_texture().get_image().get_region(box20).save_png((b20 as String).substr(8))
		break

	# `reelclip=<dir>`: each of the screen's commercials alone, from its first
	# moment to its last, a frame every 33 ms, in `<dir>/<i>/`, cropped to it.
	for a21 in OS.get_cmdline_user_args():
		if not (a21 as String).begins_with("reelclip="):
			continue
		var scr21 := Router.current as StationScreen
		if scr21 == null or scr21._board == null or not scr21._board.screen():
			print("  reelclip: no screen on this board")
			break
		for c21 in scr21._work.get_children():
			(c21 as CanvasItem).visible = false
		scr21._board_lamp.power_on(true)
		var bd21 := scr21._board
		var dir21 := (a21 as String).substr(9)
		for ci in BoardCommercial.count():
			DirAccess.make_dir_recursive_absolute("%s/%d" % [dir21, ci])
			bd21.reel = ci
			bd21.reel_from = PostingBoard._t()
			var f21 := 0
			while PostingBoard._t() - bd21.reel_from < BoardCommercial.LENGTH:
				await RenderingServer.frame_post_draw
				var o := bd21.get_global_transform() * Vector2(PostingBoard.FRAME_W + 8.0, PostingBoard.FRAME_W + 8.0)
				bd21.get_viewport().get_texture().get_image().get_region(Rect2i(Vector2i(o), Vector2i(107, 170))).save_png(
					"%s/%d/frame_%03d.png" % [dir21, ci, f21])
				f21 += 1
				await tree.create_timer(0.033).timeout
			print("  reelclip: %s, %d frames" % [BoardCommercial.NAMES[ci], f21])
		bd21.reel = -1
		break

	# `boardpool=<dir>`: every piece in this level's pool, laid out in rows with
	# its number, page after page (`pool_01.png` and on), the work taken down so
	# nothing hides them -- for checking new pieces one by one.
	for a19 in OS.get_cmdline_user_args():
		if not (a19 as String).begins_with("boardpool="):
			continue
		var scr19 := Router.current as StationScreen
		if scr19 == null or scr19._board == null or scr19._board_lamp == null:
			print("  boardpool: no board on screen")
			break
		var dir19 := (a19 as String).substr(10)
		DirAccess.make_dir_recursive_absolute(dir19)
		for c19 in scr19._work.get_children():
			(c19 as CanvasItem).visible = false
		scr19._board_lamp.power_on(true)
		var bd19 := scr19._board
		bd19.gallery_from = 0
		var page19 := 0
		while bd19.gallery_from < bd19.gallery_count():
			bd19.queue_redraw()
			await tree.process_frame
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			page19 += 1
			var box19 := Rect2i(scr19._board_lamp.get_global_rect())
			scr19._board_lamp.get_viewport().get_texture().get_image().get_region(box19).save_png(
				"%s/pool_%02d.png" % [dir19, page19])
			if bd19.gallery_shown <= 0:
				print("  boardpool: piece %d does not fit on a page" % bd19.gallery_from)
				break
			bd19.gallery_from += bd19.gallery_shown
		print("  boardpool: %d pieces on %d pages to %s" % [bd19.gallery_count(), page19, dir19])
		break

	# `boardseeds=<dir>`: the Hiring Board as `seedcount=N` (12) different
	# stations would show it -- its pieces and where they land are keyed to the
	# station's number -- settled, one still each, `seed_001.png` and on.
	for a18 in OS.get_cmdline_user_args():
		if not (a18 as String).begins_with("boardseeds="):
			continue
		var scr18 := Router.current as StationScreen
		if scr18 == null or scr18._board == null or scr18._board_lamp == null:
			print("  boardseeds: no board on screen")
			break
		var count18 := 12
		for b18 in OS.get_cmdline_user_args():
			if (b18 as String).begins_with("seedcount="):
				count18 = int((b18 as String).substr(10))
		var dir18 := (a18 as String).substr(11)
		DirAccess.make_dir_recursive_absolute(dir18)
		scr18._board_lamp.power_on(true)
		for s18 in range(1, count18 + 1):
			scr18._board.station_seed = s18
			await tree.process_frame
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var box18 := Rect2i(scr18._board_lamp.get_global_rect())
			scr18._board_lamp.get_viewport().get_texture().get_image().get_region(box18).save_png(
				"%s/seed_%03d.png" % [dir18, s18])
		print("  boardseeds: %d boards to %s" % [count18, dir18])
		break

	# `railclip=<dir>`: the elevator (`StationSpine`) as the game shows it, a
	# frame every `clipms=M` (33) for `clipframes=N` (90), on the real clock its
	# pictures play on -- to set against the frames `tools/room_stage/rail/`
	# holds. Each file is named for the milliseconds it was taken at.
	for a15 in OS.get_cmdline_user_args():
		if not (a15 as String).begins_with("railclip="):
			continue
		var scr15 := Router.current as StationScreen
		if scr15 == null or scr15._spine == null:
			print("  railclip: no elevator on screen")
			break
		var frames15 := 90
		var step15 := 33.0
		for b15 in OS.get_cmdline_user_args():
			if (b15 as String).begins_with("clipframes="):
				frames15 = int((b15 as String).substr(11))
			elif (b15 as String).begins_with("clipms="):
				step15 = float((b15 as String).substr(7))
		var dir15 := (a15 as String).substr(9)
		DirAccess.make_dir_recursive_absolute(dir15)
		var sp15 := scr15._spine
		var box15 := Rect2i(sp15.get_global_rect())
		for i15 in frames15:
			await tree.create_timer(step15 / 1000.0).timeout
			await RenderingServer.frame_post_draw
			var img15 := sp15.get_viewport().get_texture().get_image().get_region(box15)
			img15.save_png("%s/frame_%03d_%d.png" % [dir15, i15, Time.get_ticks_msec()])
		print("  railclip: %d frames of %s to %s" % [frames15, box15, dir15])
		break

	# `labclip=<dir>`: the Laboratory as a run of frames on its own clock,
	# `clipframes=N` (90) `clipms=M` apart (66), from `clipfrom=S` seconds after
	# it powered on (6, settled) -- its lights, its monitor, its glass, as the
	# game moves them. The lab's 740x431 alone, like `roomshot=`.
	for a14 in OS.get_cmdline_user_args():
		if not (a14 as String).begins_with("labclip="):
			continue
		var scr14 := Router.current as StationScreen
		if scr14 == null or scr14._lab == null or not scr14._lab.is_visible_in_tree():
			print("  labclip: no lab on screen")
			break
		var frames14 := 90
		var step14 := 66.0
		var from14 := 6.0
		for b14 in OS.get_cmdline_user_args():
			if (b14 as String).begins_with("clipframes="):
				frames14 = int((b14 as String).substr(11))
			elif (b14 as String).begins_with("clipms="):
				step14 = float((b14 as String).substr(7))
			elif (b14 as String).begins_with("clipfrom="):
				from14 = float((b14 as String).substr(9))
		var dir14 := (a14 as String).substr(8)
		DirAccess.make_dir_recursive_absolute(dir14)
		var lab14 := scr14._lab
		var box14 := Rect2i(Vector2i(lab14.get_global_rect().position), Vector2i(LabScene.PANEL))
		for i14 in frames14:
			LabScene.pin_clock = from14 + float(i14) * step14 / 1000.0
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img14 := lab14.get_viewport().get_texture().get_image().get_region(box14)
			img14.save_png("%s/frame_%03d.png" % [dir14, i14])
		print("  labclip: %d frames from %.2fs to %s" % [frames14, from14, dir14])
		break

	# `yardclip=<dir>`: the Shipyard as a run of frames on its own clock,
	# `clipframes=N` (90) `clipms=M` apart (66), from `clipfrom=S` seconds after
	# its TV powered on (0) -- the power-on, the drones flying in, anything
	# `yardev=` fires. `yardbuy=I:S` buys service I at S seconds, as a click does;
	# `yardbuy=take:S` presses TAKE IT, and the clip goes on with the dock open
	# over the yard; `yardbuy=backout:S` presses the dock's BACK OUT.
	for a13 in OS.get_cmdline_user_args():
		if not (a13 as String).begins_with("yardclip="):
			continue
		var scr13 := Router.current as StationScreen
		if scr13 == null or scr13._scene == null or not scr13._scene.is_visible_in_tree():
			print("  yardclip: no yard on screen")
			break
		var frames13 := 90
		var step13 := 66.0
		var from13 := 0.0
		var buys13: Array = []
		for b13 in OS.get_cmdline_user_args():
			if (b13 as String).begins_with("clipframes="):
				frames13 = int((b13 as String).substr(11))
			elif (b13 as String).begins_with("clipms="):
				step13 = float((b13 as String).substr(7))
			elif (b13 as String).begins_with("clipfrom="):
				from13 = float((b13 as String).substr(9))
			elif (b13 as String).begins_with("yardbuy="):
				for pair in (b13 as String).substr(8).split(","):
					var kv13 := pair.split(":")
					var key13 := {"take": -1, "backout": -2}
					buys13.append([int(key13.get(kv13[0], int(kv13[0]) if kv13[0].is_valid_int() else -9)), float(kv13[1]), false])
		var dir13 := (a13 as String).substr(9)
		DirAccess.make_dir_recursive_absolute(dir13)
		var yard13 := scr13._scene
		var box13 := Rect2i(Vector2i(yard13.get_global_rect().position), Vector2i(YardScene.W, YardScene.H))
		for i13 in frames13:
			var s13 := from13 + float(i13) * step13 / 1000.0
			for bb: Array in buys13:
				if not bb[2] and s13 >= float(bb[1]):
					bb[2] = true
					var hp13 := Run.hp
					var cr13 := Run.credits
					if int(bb[0]) == -2:
						var ts13: TransferScreen = null
						if Router.dock != null:
							for c13 in Router.dock.get_children():
								if c13 is TransferScreen:
									ts13 = c13
						if ts13 != null:
							ts13._back_out()
						print("  yardbuy backout at %.2fs: %s, hull %s, credits %d -> %d" % [s13,
							"backed out" if ts13 != null else "no dock open", Run.hull.name, cr13, Run.credits])
						continue
					if int(bb[0]) < 0:
						var was13 := Run.hull.name
						var u13 := Time.get_ticks_usec()
						scr13._on_yard_take()
						print("  yardbuy take at %.2fs: hull %s -> %s, credits %d -> %d, %.1f ms" % [s13, was13, Run.hull.name, cr13, Run.credits, (Time.get_ticks_usec() - u13) / 1000.0])
						continue
					scr13._on_yard_service(int(bb[0]))
					print("  yardbuy %d at %.2fs: hull %d -> %d of %d, credits %d -> %d" % [int(bb[0]), s13, hp13, Run.hp, Run.max_hp(), cr13, Run.credits])
			if is_instance_valid(yard13):
				yard13.step_to(s13)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			if not is_instance_valid(yard13):
				# the station went, and the yard with it
				print("  yardclip: the yard closed at %.2fs" % s13)
				frames13 = i13
				break
			var img13 := yard13.get_viewport().get_texture().get_image().get_region(box13)
			img13.save_png("%s/frame_%03d.png" % [dir13, i13])
		print("  yardclip: %d frames from %.2fs to %s" % [frames13, from13, dir13])
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
