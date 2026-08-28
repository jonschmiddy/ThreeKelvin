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
	Router.show_sector()
	for i in 90:
		await RenderingServer.frame_post_draw
	var tag := "_group" if want_group else ""
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
	# RULING 1b IS A HOVER STATE, so a screenshot cannot reach it by waiting --
	# there is no pointer. Setting it directly is the only way to photograph the
	# preview, and the preview is half of what rulings 1 and 1b are.
	if "hover" in OS.get_cmdline_user_args():
		var s := Router.current as SectorScreen
		if s != null:
			for i2 in n.options.size():
				var g := StringName(OptionTable.by_id(n.options[i2]).get("group", &""))
				if g == &"":
					continue
				s._hover_group = g
				s._hover_index = i2
				s._rebuild_options(n)
				break
		tag += "_hover"
		for i3 in 30:
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
