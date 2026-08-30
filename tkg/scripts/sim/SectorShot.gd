extends RefCounted

## The arrival screen, photographed:
##   godot --path . -- sectorshot [seed=N] [group]
##
## NEEDS A WINDOW. Under `--headless` the dummy display server never emits
## `frame_post_draw`, so nothing is captured and it looks exactly like a hang.
##
## IT EXISTS BECAUSE 8b IS A LAYOUT. `ENCOUNTER_FLOW.md` beat 2 is a drawing of a
## screen -- a group box, a check badge, a row per option -- and none of that is
## something an assert can look at. The list either reads or it does not.
##
## `group` hunts for a system carrying an EXCLUSIVE set, because that is the half
## of the design with no fallback: an independent option is one row and a group is
## the whole of rulings 1 and 1b. Without one on screen the shot proves the easy
## case.


## How many of a grid's icons are actually on screen.
func _showing(g: Control) -> int:
	var n := 0
	for c in g.get_children():
		if c is ItemIcon and (c as Control).visible:
			n += 1
	return n


## Every option card on screen, in the order they are laid out.
func _cards(root: Node, out: Array) -> void:
	if root == null:
		return
	for c in root.get_children():
		if c is EncounterDrawer.OptionCard:
			out.append(c)
		_cards(c, out)


## Every button in the sector's drawer, however deep it is nested.
func _buttons(root: Node) -> Array[Button]:
	var out: Array[Button] = []
	if root == null:
		return out
	for c in root.get_children():
		if c is Button and (c as Button).visible:
			out.append(c)
		out.append_array(_buttons(c))
	return out


func run(tree: SceneTree) -> void:
	await tree.process_frame
	Rng.forced = 4242
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("seed="):
			Rng.forced = int((a as String).substr(5))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var want_group := "group" in OS.get_cmdline_user_args()
	# `start` photographs the node the run opens on, which is the one place with
	# its own drawer height.
	var target := Run.at if "start" in OS.get_cmdline_user_args() else _find(want_group)
	if target < 0:
		print("no system %s found on seed %d"
			% ["with a group" if want_group else "with options", Rng.forced])
		tree.quit()
		return
	# Put the ship there rather than flying to it. The screen reads the node under
	# the ship and nothing else, so a legal route is not part of what is measured.
	Run.at = target
	var n: MapGen.MapNode = Run.node_at()
	OptionTable.ensure(n)
	print("  %s -- danger %d, %d options: %s"
		% [MapGen.star_name(n), n.danger, n.options.size(), n.options])
	# A SYSTEM WITH NOTHING LEFT IN IT, which is a fourth drawer state and the
	# only one no mode could reach. `open=` and `take=` walk LIST -> OPTION ->
	# RESULT, and all three of those need a system that still has options; the
	# band that a FINISHED system gets is the one thing they cannot photograph.
	# Marking the claims directly rather than resolving each option: what is
	# being looked at is the height of a drawer with an empty list, and running
	# four payouts to get there would put their loot in the picture.
	if "spent" in OS.get_cmdline_user_args():
		for si in n.options.size():
			n.taken.append(MapGen.OPTION_SITE + si)
	Router.show_sector()
	for i in 90:
		await RenderingServer.frame_post_draw
	var tag := "_group" if want_group else ""
	# WHAT AN EXCLUSIVE SET LOOKS LIKE WHEN YOU POINT AT ONE OF IT. RULING 1 is
	# a hover now rather than a box, so there is no frame in which it is visible
	# by itself -- and `Input.parse_input_event` plus `warp_mouse` does not drive
	# GUI in a window that does not have focus, which has produced false failures
	# here before. Notifying the card is what a pointer over it would do, and it
	# is the same "drive the screen directly" the open= and take= modes use.
	if "hover" in OS.get_cmdline_user_args():
		var cards: Array = []
		_cards(Router.current, cards)
		var lit: EncounterDrawer.OptionCard = null
		for c in cards:
			if not (c as EncounterDrawer.OptionCard).kin.is_empty():
				lit = c
				break
		if lit == null:
			print("  no exclusive set on screen")
		else:
			lit.notification(Control.NOTIFICATION_MOUSE_ENTER)
			print("  %d cards, %d in a set with the one pointed at"
				% [cards.size(), lit.kin.size()])
			for f in 4:
				await RenderingServer.frame_post_draw
		tag += "_hover"
	if "spent" in OS.get_cmdline_user_args():
		tag += "_spent"
		var sc := Router.current as SectorScreen
		if sc != null:
			print("  drawer band: %.0f  (DRAWER_H %d)"
				% [sc._quiet_wrap.size.y, SectorScreen.DRAWER_H])
	# THE DRAWER HAS THREE STATES AND A SCREENSHOT ONLY EVER CATCHES THE FIRST.
	# `open=N` clicks into an option, `take=N` resolves one of its choices, so
	# LIST -> OPTION -> RESULT can each be photographed. Driving the screen
	# directly rather than faking a pointer, for the same reason the hover shot
	# does: there is no pointer.
	# `combat` swaps the drawer for the hand, which is the only way to see
	# whether the two bands actually match -- they are mutually exclusive, so no
	# single frame shows both and the comparison is between two screenshots.
	# `menu` proves the view memory does not leak into the launcher's galaxy.
	# It pans the starchart's remembered view a long way off centre, opens the
	# menu, and reports where the menu's own chart actually ended up -- which is
	# the bug: both screens build the same MapChart, and the memory is on the
	# class rather than on the instance.
	# `region` proves what LOCAL REGION does to an arrival. ON, the chart must
	# re-frame on where you are standing; OFF, it must come back exactly where
	# you left it. Both are one flag and one code path, so one of them silently
	# doing the other's job is the failure to watch for.
	if "region" in OS.get_cmdline_user_args():
		StarchartScreen._view_zoom = 3.0
		StarchartScreen._view_pan = Vector2(-420.0, 260.0)
		StarchartScreen._view_map = Run.map.size()
		for on in [false, true]:
			StarchartScreen._region_on = on
			Router.show_starchart()
			# THREE FRAMES, NOT THIRTY. A glide runs 0.55s -- about thirty-three
			# frames -- so sampling at thirty reads almost the end state and
			# cannot tell a snap from an animation nearly finished. If the view
			# is already final here, nothing tweened.
			for iA in 3:
				await RenderingServer.frame_post_draw
			var st := Router.current as StarchartScreen
			if st != null and st._chart != null:
				print("  LOCAL REGION %-3s -> pan %s zoom %.2f"
					% ["ON" if on else "OFF", st._chart.pan, st._chart.zoom])
		tree.quit()
		return
	if "menu" in OS.get_cmdline_user_args():
		StarchartScreen._view_zoom = 3.0
		StarchartScreen._view_pan = Vector2(-420.0, 260.0)
		StarchartScreen._view_map = Run.map.size()
		Router.show_launcher()
		for i8 in 40:
			await RenderingServer.frame_post_draw
		var ls := Router.current as LauncherScreen
		if ls != null and ls._sky != null:
			print("  remembered pan %s zoom %.2f" % [StarchartScreen._view_pan,
				StarchartScreen._view_zoom])
			print("  menu galaxy  pan %s zoom %.2f" % [ls._sky.pan, ls._sky.zoom])
		# AND THE HALF THAT IS SUPPOSED TO WORK. Gating the memory behind a flag
		# could as easily have turned it off everywhere; the starchart has to
		# still come back where it was left.
		Router.show_starchart()
		for i9 in 30:
			await RenderingServer.frame_post_draw
		var ss := Router.current as StarchartScreen
		if ss != null and ss._chart != null:
			print("  starchart    pan %s zoom %.2f" % [ss._chart.pan, ss._chart.zoom])
		tree.root.get_texture().get_image().save_png("user://menu.png")
		print("wrote ", ProjectSettings.globalize_path("user://menu.png"))
		tree.quit()
		return
	if "buttons" in OS.get_cmdline_user_args():
		# DOES THE WORD FIT THE BOX? `custom_minimum_size` is a floor, so a
		# label too long for it does not overflow -- the BUTTON grows, silently,
		# and the row stops being the width it was designed to be. Measuring the
		# text is the only way to know whether 104 is a size or a wish.
		Router.show_sector()
		for ib in 20:
			await RenderingServer.frame_post_draw
		var font := ThemeDB.fallback_font
		var worst := 0.0
		for word in ["PLOT NEXT JUMP", "SECTOR LOOT - 12", "DOCK", "SUMMARY",
				"HARVEST", "DECIDE LATER"]:
			var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1,
				UITheme.FS_SMALL).x
			worst = maxf(worst, w)
			print("  %-18s %.0f px" % [word, w])
		print("  widest %.0f, button %.0f, padding either side %.0f"
			% [worst, EncounterDrawer.BTN.x, (EncounterDrawer.BTN.x - worst) * 0.5])
		# AND THE REAL ONES ON SCREEN. A button whose label does not fit its
		# minimum does not clip -- it grows, and the row quietly stops being the
		# width it was designed to be.
		var st2 := Router.current as SectorScreen
		var grew := 0
		for b in _buttons(st2):
			# Only the ones sized to the box. Choice buttons in the OPTION
			# state are 150 wide by design and would report as overflows
			# forever. Option cards are not buttons at all any more.
			if b.custom_minimum_size.x != EncounterDrawer.BTN.x:
				continue
			if b.size.x > EncounterDrawer.BTN.x + 0.5:
				grew += 1
				print("  GREW: %-20s %.0f > %.0f" % [b.text, b.size.x,
					EncounterDrawer.BTN.x])
		print("  %d drawer buttons wider than the box" % grew)
		tree.quit()
		return
	if "transfer" in OS.get_cmdline_user_args():
		Run.hand_size_override = 5
		# A PHOTOGRAPH, and nothing else. This mode had grown eight probes
		# chasing a bug that turned out to be a signal with no listener, and
		# every one of them asserted on the model -- the half that was never
		# broken. `-- transfertest` now does that properly and headlessly, on
		# what is DRAWN, so what is left here is the job a shot is actually for.
		var n0: MapGen.MapNode = Run.node_at()
		var tiers0: Array[StringName] = [&"legendary", &"contraband", &"rare",
			&"exotic", &"common", &"artifact", &"epic"]
		var want0 := ["2x2", "4x1", "1x1", "3x1", "2x1", "1x1", "2x1"]
		var k0 := 0
		var pile := Run.sector_jetsam(n0)
		for shape0 in want0:
			for row0 in MaterialTable.all():
				if String(row0.get("cells", "")) != shape0:
					continue
				var mm := MaterialData.of(row0)
				mm.tier = tiers0[k0 % tiers0.size()]
				k0 += 1
				pile.items.append(mm)
				break
		pile.items.append(LootGen.roll_module(3, &"", false, Rng.derive(&"look", 7)))
		pile.items.append(CreditChit.of(240))

		Router.show_sector()
		for it in 40:
			await RenderingServer.frame_post_draw
		var st := Router.current as SectorScreen
		if st != null:
			st._open_sector_loot()
			# MID-SWEEP. Three frames in, the line is partway down and the
			# things behind it are the only ones showing -- the frame worth
			# photographing, and the one a settled shot cannot tell apart from
			# a broken container.
			for iu in 3:
				await RenderingServer.frame_post_draw
			tree.root.get_texture().get_image().save_png("user://sector_scan.png")
			print("wrote ", ProjectSettings.globalize_path("user://sector_scan.png"))
			for iu2 in 90:
				await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png("user://sector_transfer.png")
		print("wrote ", ProjectSettings.globalize_path("user://sector_transfer.png"))
		tree.quit()
		return
	if "status" in OS.get_cmdline_user_args():
		Run.hand_size_override = 5
		# WHICH CONTACT, because hull SIZE is what the readouts' placement
		# depends on: each hangs under its own ship, so two hulls of different
		# heights put their readouts on different lines. `foe=leviathan` is the
		# case that shows it; the cutter is the case that hides it.
		var foe := &"cutter"
		for af in OS.get_cmdline_user_args():
			if (af as String).begins_with("foe="):
				foe = StringName((af as String).substr(4))
		Router.start_combat(DB.enemies[foe], [], false)
		for id in 60:
			await RenderingServer.frame_post_draw
		var ss := Router.current as SectorScreen
		if ss != null and ss.combat != null:
			var cs := ss.combat
			# THE BAR MUST NOT MOVE. Statuses arrive and leave every turn, and a
			# hull bar that shifts when one does is a readout you have to find
			# again mid-fight.
			var bar_before: float = ss._self_bar.global_position.y
			print("  BEFORE plate y %.0f h %.0f ; bar local y %.0f"
				% [ss._self_plate.position.y, ss._self_plate.size.y,
					ss._self_bar.position.y])
			cs.brace = 5
			cs.block = 3
			cs.lock_on = 2
			cs.negate_next = true
			cs.feedback = 2
			cs.adapt_bonus = 1
			cs.drone_brace = 1
			ss._refresh_player()
			for ie in 4:
				await RenderingServer.frame_post_draw
			# THE ROW HAS TO FIT UNDER THE SHIP. Icons were the answer to a row
			# of words that grew wider than the hull it belonged to, so the
			# width is the number that says whether it worked.
			print("  AFTER  plate y %.0f h %.0f ; bar local y %.0f"
				% [ss._self_plate.position.y, ss._self_plate.size.y,
					ss._self_bar.position.y])
			print("  hull bar y %.0f before, %.0f with 7 statuses  (must match)"
				% [bar_before, ss._self_bar.global_position.y])
			print("  status row %.0f wide, %d chips"
				% [ss._player_chips.size.x, ss._player_chips.get_child_count()])
			var sv := ss._view.ship_view()
			# WHERE THE TWO READOUTS ACTUALLY LAND, which is a question two
			# different rules answer. Yours hangs `PLATE_AIR` below the
			# sprite's last opaque row, so it tracks YOUR hull. Theirs is
			# simply the next child after a fixed 240x120 art box, so the
			# contact's size does not move it at all -- measured across
			# cutter, hulk, whale and leviathan it spans four pixels, while
			# yours does not move.
			#
			# RULED: leave them on their own rules. The gap is a steady four
			# to six pixels and yours hugging your ship is what makes it read
			# as belonging to the ship. Swapping YOUR hull is the case that
			# would separate them, and that is the case to judge it on.
			print("  your name y %.0f ; their name y %.0f"
				% [ss._self_name.global_position.y,
					ss.view_slot(0)._name.global_position.y])
			print("  hull centre x %.0f ; plate centre x %.0f  (must match)"
				% [sv.position.x + sv.size.x * 0.5 + sv.ship_offset_x(),
					ss._self_plate.position.x + ss._self_plate.size.x * 0.5])
			print("  hull bottom y %.0f ; plate top y %.0f"
				% [sv.position.y + sv.size.y * 0.5 + sv.ship_bottom_y(),
					ss._self_plate.position.y])
		# THE DRIFT, SAMPLED OVER TIME. Both ships have to move and the readouts
		# bolted to them have to not: your bob is inside the canvas and the
		# plate takes the offset back out, so a plate that drifts means
		# `ship_bottom_y` stopped subtracting it.
		if ss != null:
			var svb := ss._view.ship_view()
			var slb: EnemySlot = ss.view_slot(0)
			var you: Array[int] = []
			var them: Array[float] = []
			var plate: Array[float] = []
			# 240 FRAMES, BECAUSE THE CYCLE IS FOUR SECONDS. Sampled over 40
			# the ship sat at the top of its arc the whole time and the range
			# came out 2..2 -- a still ship and a slow one are the same
			# reading through too short a window.
			for ih in 240:
				await RenderingServer.frame_post_draw
				you.append(svb.bob_offset())
				them.append(slb.art.position.y)
				plate.append(ss._self_plate.position.y)
			print("  your bob spans %d..%d  (must not be 0..0)"
				% [you.min(), you.max()])
			print("  their drift spans %.0f..%.0f  (must not be 0..0)"
				% [them.min(), them.max()])
			print("  plate y spans %.0f..%.0f  (must NOT move)"
				% [plate.min(), plate.max()])
		tree.root.get_texture().get_image().save_png("user://sector_status.png")
		print("wrote ", ProjectSettings.globalize_path("user://sector_status.png"))

		# EVERY GLYPH AT ONCE, because a status row only ever shows the handful
		# the fight happens to have produced. Half of these cannot be reached
		# without a specific card in a specific hand, and an icon nobody has
		# looked at is an icon nobody has checked.
		var sheet := PanelContainer.new()
		sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sheet.add_theme_stylebox_override("panel",
			UITheme.flat(Color(0.031, 0.043, 0.067, 1.0), Color(0, 0, 0, 0), 0, 24, 24))
		tree.root.add_child(sheet)
		var grid := HFlowContainer.new()
		grid.add_theme_constant_override("h_separation", 18)
		grid.add_theme_constant_override("v_separation", 14)
		sheet.add_child(grid)
		for kind in [&"brace", &"block", &"lock", &"slip", &"salvo", &"feedback",
				&"adapt", &"drone", &"wasp", &"charging", &"peaceful", &"unknown"]:
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", 4)
			cell.alignment = BoxContainer.ALIGNMENT_CENTER
			var big := StatusChip.Glyph.new(kind, Color("#7a94b4"))
			big.custom_minimum_size = Vector2(StatusChip.ICON, StatusChip.ICON) * 4.0
			big.scale = Vector2(4, 4)
			var pad := Control.new()
			pad.custom_minimum_size = Vector2(StatusChip.ICON, StatusChip.ICON) * 4.0
			pad.add_child(big)
			cell.add_child(pad)
			cell.add_child(StatusChip.make(kind, "9", Color("#7a94b4"), ""))
			var cap := UITheme.body(String(kind), UITheme.COLD, 10)
			cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(cap)
			grid.add_child(cell)
		for ig in 6:
			await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png("user://status_sheet.png")
		print("wrote ", ProjectSettings.globalize_path("user://status_sheet.png"))
		tree.quit()
		return
	if "entrance" in OS.get_cmdline_user_args():
		Run.hand_size_override = 5
		Router.start_combat(DB.enemies[&"cutter"], [], false)
		var se := Router.current as SectorScreen
		# SAMPLED EARLY AND LATE, and the early sample is the one that matters.
		# The last time an animation was checked here it was sampled at 30 frames
		# against a run of 33, which cannot tell a glide from a snap. Six frames
		# is a tenth of the way through half a second, so a ship that is NOT
		# animating reads as zero here and fails loudly.
		for i8 in 6:
			await RenderingServer.frame_post_draw
		var sl0: EnemySlot = se.view_slot(0) if se != null else null
		print("  contact x at 6 frames:  %.0f  (must not be 0)"
			% (sl0.art.position.x if sl0 != null else -1.0))
		tree.root.get_texture().get_image().save_png("user://sector_entrance.png")
		for i9 in 90:
			await RenderingServer.frame_post_draw
		print("  contact x at 96 frames: %.0f  (must be 0)"
			% (sl0.art.position.x if sl0 != null else -1.0))
		# THE RETICLE, which reads a rect that just changed meaning. The two
		# boxes have to coincide once the ship has landed, or the brackets
		# frame empty space.
		if sl0 != null:
			sl0.set_hot(true)
			for ic in 3:
				await RenderingServer.frame_post_draw
			print("  art in slot %s ; holder %s  (must match)"
				% [sl0.art.get_global_rect(), sl0.holder_rect()])
			tree.root.get_texture().get_image().save_png("user://sector_reticle.png")
			print("wrote ", ProjectSettings.globalize_path("user://sector_reticle.png"))
		print("wrote ", ProjectSettings.globalize_path("user://sector_entrance.png"))
		tree.quit()
		return
	if "pile" in OS.get_cmdline_user_args():
		Run.hand_size_override = 5
		Router.start_combat(DB.enemies[&"cutter"], [], false)
		for ia in 60:
			await RenderingServer.frame_post_draw
		var sp := Router.current as SectorScreen
		if sp != null:
			# THE DISCARD, because it is the pile that is empty when a fight
			# opens and so the one whose listing is easy to get wrong. Fed from
			# the draw pile so the cards are real ones.
			# NINETEEN, so the flow WRAPS and the scroll has something to
			# scroll. A one-card discard is the case that cannot fail: it
			# fits on any row, at any column count, with or without the
			# ScrollContainer working at all.
			var seed_from: Array = sp.combat.deck.duplicate()
			while sp.combat.discard.size() < 19 and not seed_from.is_empty():
				for c9 in seed_from:
					sp.combat.discard.append(c9)
					if sp.combat.discard.size() >= 19:
						break
			sp._show_pile("DISCARD PILE", sp.combat.discard, false)
			for ib in 6:
				await RenderingServer.frame_post_draw
			print("  listed %d of %d discards"
				% [sp._pile_panel.get_child(0).get_child(1).get_child(0)
					.get_child_count(), sp.combat.discard.size()])
		tree.root.get_texture().get_image().save_png("user://sector_pile.png")
		print("wrote ", ProjectSettings.globalize_path("user://sector_pile.png"))
		tree.quit()
		return
	if "combat" in OS.get_cmdline_user_args():
		Run.hand_size_override = 5
		Router.start_combat(DB.enemies[&"cutter"], [], false)
		for i6 in 100:
			await RenderingServer.frame_post_draw
		var sc := Router.current as SectorScreen
		# THE HAIL GATE, BOTH WAYS. Bracing must leave it open and shooting must
		# close it, and one flag serving both is exactly the shape that ends up
		# doing only one of them.
		if sc != null and sc.combat != null:
			var c0 := sc.combat
			print("  hail before anything: %s (%s)"
				% [c0.can_hail(), c0.hail_reason()])
			c0.block += 5
			print("  hail after bracing:   %s (%s)"
				% [c0.can_hail(), c0.hail_reason()])
			print("  flee before anything: %s (%s)"
				% [c0.can_flee(), c0.flee_reason()])
			c0.flee_failed = true
			print("  flee after a miss:    %s (%s)"
				% [c0.can_flee(), c0.flee_reason()])
			c0.flee_failed = false
			c0.damage_enemy(1, 1, "probe")
			print("  hail after a shot:    %s (%s)"
				% [c0.can_hail(), c0.hail_reason()])
			print("  flee after a shot:    %s (%s)   <- shooting must NOT block it"
				% [c0.can_flee(), c0.flee_reason()])
		if sc != null:
			# A FULL DISCARD, because that is the state that was broken and an
			# opening hand never shows it: the stack drew its back cards above
			# its own box and painted them across FLEE.
			sc._discard_pile.set_count(9, "DISCARD")
			sc._draw_pile.set_count(14, "DRAW")
			for i7 in 4:
				await RenderingServer.frame_post_draw
		if sc != null:
			print("  hand band: %.0f  drawer band: %.0f  (DRAWER_H %d)"
				% [sc._hand_wrap.size.y, sc._quiet_wrap.size.y, SectorScreen.DRAWER_H])
			# WHAT EACH RAIL ACTUALLY MEASURES, because a minimum is not a size:
			# a button's stylebox padding can push it well past what it was asked
			# for, and the band then reports a number no single constant explains.
			var rails: Array[Control] = [sc._end_button, sc._hail_button]
			for r2 in rails:
				if r2 != null:
					print("    %-10s %.0f" % [r2.text, r2.size.y])
			var col: Control = sc._end_button.get_parent()
			var tot := 0.0
			for ch in col.get_children():
				tot += (ch as Control).size.y
			print("    right rail children total %.0f in %.0f"
				% [tot, col.size.y])
			for ch2 in col.get_children():
				print("      R %-14s %.0f" % [(ch2 as Control).name, (ch2 as Control).size.y])
			# WHERE THE CARDS ACTUALLY SIT. The hand stretches to the row and the
			# cards are placed against a baseline inside it, so the gap above and
			# below them is not any constant in the file -- it has to be read.
			# WHERE A HOVER WOULD SPRING BACK TO. It is captured in `_ready`,
			# which fires before the hand positions the card, so it was always
			# zero -- and a hovered card animated to the top of the band rather
			# than back to its own row.
			print("    card base_y %.0f (rest y %.0f)"
				% [(sc._hand.get_child(0) as CardView)._base_y,
					(sc._hand.get_child(0) as Control).position.y])
			# IN ROW COORDS, which is the only frame the pile labels share. The
			# card's own y is relative to the hand, so it reads 8 whether the
			# hand is at the top of the row or the bottom of it.
			var pv: Control = sc._draw_pile
			# WHERE A HOVERED CARD'S TOP EDGE IS, against where the rails start.
			# The lift is -8 from the resting baseline, so this is the line the
			# ENERGY and END TURN boxes are meant to square up to.
			# WHERE THE SHIP ACTUALLY IS, against where the plate went. The art
			# Control is not the slot -- it sizes and animates itself -- so the
			# offset from its rect centre is a number to read, not to reason to.
			var sv: Control = sc._view.ship_view()
			print("    ship rect %s ; anchor %s ; plate at %s"
				% [sv.get_rect(), sc._view.self_anchor(),
					sc._self_plate.position if sc._self_plate != null else "-"])
			var e0: Control = sc._energy.get_parent().get_parent()
			print("    hovered card top %.0f; rail first box top %.0f"
				% [sc._hand.position.y
						+ (sc._hand.get_child(0) as Control).position.y - 8.0,
					e0.position.y])
			print("    hand y %.0f; card bottom in row %.0f; pile label %.0f"
				% [sc._hand.position.y,
					sc._hand.position.y + (sc._hand.get_child(0) as Control).position.y
						+ (sc._hand.get_child(0) as Control).size.y,
					pv.position.y + SectorScreen.PileView.H + 14])
			print("    hand view %.0f tall; card top %.0f, bottom %.0f"
				% [sc._hand.size.y,
					(sc._hand.get_child(0) as Control).position.y,
					(sc._hand.get_child(0) as Control).position.y
						+ (sc._hand.get_child(0) as Control).size.y])
			var lcol: Control = sc._energy.get_parent().get_parent().get_parent()
			print("    left rail %.0f" % lcol.size.y)
			for ch3 in lcol.get_children():
				print("      L %-14s %.0f" % [(ch3 as Control).name, (ch3 as Control).size.y])
		tree.root.get_texture().get_image().save_png("user://sector_combat.png")
		print("wrote ", ProjectSettings.globalize_path("user://sector_combat.png"))
		tree.quit()
		return
	var s0 := Router.current as SectorScreen
	for a2 in OS.get_cmdline_user_args():
		if (a2 as String).begins_with("open=") and s0 != null:
			s0._open = int((a2 as String).substr(5))
			s0._dstate = SectorScreen.Drawer.OPTION
			s0._refresh()
			tag += "_open"
			for i4 in 20:
				await RenderingServer.frame_post_draw
		elif (a2 as String).begins_with("take=") and s0 != null:
			s0._take(n, s0._open, int((a2 as String).substr(5)))
			tag += "_result"
			for i5 in 20:
				await RenderingServer.frame_post_draw
	var sc2 := Router.current as SectorScreen
	if sc2 != null:
		print("  drawer band: %.0f  hand band: %.0f  (DRAWER_H %d)"
			% [sc2._quiet_wrap.size.y, sc2._hand_wrap.size.y, SectorScreen.DRAWER_H])
	var path := "user://sector%s.png" % tag
	tree.root.get_texture().get_image().save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))
	tree.quit()


## The first system whose options are worth photographing.
func _find(want_group: bool) -> int:
	for n in Run.map:
		var t: MapGen.MapNode = n
		if t.type != MapGen.NodeType.SYSTEM or t.cleared:
			continue
		if not OptionTable.ensure(t):
			continue
		if "fight" in OS.get_cmdline_user_args():
			# RULING 5's reading only prints on a row that opens one.
			if OptionTable.system_has_tag(t, &"fight"):
				return t.index
			continue
		if not want_group:
			return t.index
		# A group only exists when TWO members of it actually rolled here --
		# `roll_for` can draw one member of a pair and leave the other, and a box
		# around a single row is not what ruling 1 is about.
		var seen: Dictionary = {}
		for id in t.options:
			var g := StringName(OptionTable.by_id(id).get("group", &""))
			if g == &"":
				continue
			if seen.has(g):
				return t.index
			seen[g] = true
	return -1
