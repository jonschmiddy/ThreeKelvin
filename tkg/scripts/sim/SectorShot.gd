extends RefCounted

## Needs a window: headless never emits `frame_post_draw`, so it looks like a hang.
## A layout can only be looked at; `group` hunts an exclusive set, which has no fallback.
## Why: docs/why/SectorShot.md#sector-shot


## Photograph the tree and say where it went. Every shot in this file is this
## same pair of lines; the filename is the only thing that varies.
func _snap(tree: SceneTree, path: String) -> void:
	tree.root.get_texture().get_image().save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))


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
	# Claims are marked directly: no mode could photograph a finished system's empty drawer.
	# Why: docs/why/SectorShot.md#spent-system
	if "spent" in OS.get_cmdline_user_args():
		# One of each band: the point is whether the four colours read as a set.
		var bands: Array[StringName] = [MapGen.R_SUCCESS, MapGen.R_PARTIAL,
			MapGen.R_BOTCHED, MapGen.R_GONE, MapGen.R_DONE]
		for si in n.options.size():
			n.taken.append(MapGen.OPTION_SITE + si)
			n.results[si] = bands[si % bands.size()]
	Router.show_sector()
	for i in 90:
		await RenderingServer.frame_post_draw
	var tag := "_group" if want_group else ""
	if "hover" in OS.get_cmdline_user_args():
		tag += "_hover"
	if "spent" in OS.get_cmdline_user_args():
		tag += "_spent"
		var sc := Router.current as SectorScreen
		if sc != null:
			print("  drawer band: %.0f  (DRAWER_H %d)"
				% [sc._quiet_wrap.size.y, SectorScreen.DRAWER_H])
	# A screenshot only catches the first state, so the modes drive the screen directly.
	# `menu` checks view memory on the class does not leak; `region` checks re-framing on and off.
	# Why: docs/why/SectorShot.md#drawer-states
	if "region" in OS.get_cmdline_user_args():
		StarchartScreen._view_zoom = 3.0
		StarchartScreen._view_pan = Vector2(-420.0, 260.0)
		StarchartScreen._view_map = Run.map.size()
		for on in [false, true]:
			StarchartScreen._region_on = on
			Router.show_starchart()
			# Three frames, not thirty: a 0.55 s glide is 33 frames, so thirty cannot tell a snap.
			# Why: docs/why/SectorShot.md#glide-sampling
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
		# The memory must still work: gating it behind a flag could turn it off everywhere.
		Router.show_starchart()
		for i9 in 30:
			await RenderingServer.frame_post_draw
		var ss := Router.current as StarchartScreen
		if ss != null and ss._chart != null:
			print("  starchart    pan %s zoom %.2f" % [ss._chart.pan, ss._chart.zoom])
		_snap(tree, "user://menu.png")
		tree.quit()
		return
	if "buttons" in OS.get_cmdline_user_args():
		# `custom_minimum_size` is a floor: a long label grows the button, so measure the text.
		Router.show_sector()
		for ib in 20:
			await RenderingServer.frame_post_draw
		var font := ThemeDB.fallback_font
		var worst := 0.0
		for word in ["SCAN SECTOR", "SUMMARY",
				"HARVEST", "DECIDE LATER"]:
			var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1,
				UITheme.FS_SMALL).x
			worst = maxf(worst, w)
			print("  %-18s %.0f px" % [word, w])
		print("  widest %.0f, button %.0f, padding either side %.0f"
			% [worst, EncounterDrawer.BTN.x, (EncounterDrawer.BTN.x - worst) * 0.5])
		# The real buttons on screen: a label that does not fit grows the row instead of clipping.
		var st2 := Router.current as SectorScreen
		var grew := 0
		for b in _buttons(st2):
			# Only box-sized buttons: option-state choice buttons are 150 wide by design.
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
		# Eight model probes chased a signal with no listener; `-- transfertest` now does that.
		# Why: docs/why/SectorShot.md#photograph-only
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
			# Mid-sweep, three frames in: a settled shot cannot tell it from a broken container.
			for iu in 3:
				await RenderingServer.frame_post_draw
			_snap(tree, "user://sector_scan.png")
			for iu2 in 90:
				await RenderingServer.frame_post_draw
		_snap(tree, "user://sector_transfer.png")
		tree.quit()
		return
	# Emits the signal, not the refresh: the wire under test is a modifier reaching faces in hand.
	if "live" in OS.get_cmdline_user_args():
		Run.hand_size_override = 6
		Router.start_combat(DB.enemies[&"cutter"], [], false)
		for iL in 60:
			await RenderingServer.frame_post_draw
		var sl := Router.current as SectorScreen
		if sl != null and sl.combat != null:
			_snap(tree, "user://live_before.png")
			var cl := sl.combat
			for cc in cl.hand:
				print("  BEFORE %-22s printed %d  live %d" % [
					(cc as CardData).name, (cc as CardData).damage,
					cl.card_output(cc as CardData)])
			cl.lock_on = 4
			cl.adapt_bonus = 2
			cl.attacks_this_turn = 1
			Sig.player_combat_state_changed.emit()
			for iL2 in 8:
				await RenderingServer.frame_post_draw
			for cc in cl.hand:
				print("  AFTER  %-22s printed %d  live %d | %s" % [
					(cc as CardData).name, (cc as CardData).damage,
					cl.card_output(cc as CardData),
					(cc as CardData).describe_rich(cl.card_output(cc as CardData))])
			_snap(tree, "user://live_after.png")
			# Not end to end: `set_drag_preview` only parents a drag the engine started.
			# It checks a figure handed in before `setup` prints. The drag is checked by hand.
			# Why: docs/why/SectorShot.md#ghost-number
			for hv in sl._hand.get_children():
				var cvx := hv as CardView
				if cvx == null or cvx.card == null or cvx.card.damage <= 0:
					continue
				var copy := CardView.new()
				copy.live_output = cvx.live_output
				sl.add_child(copy)
				copy.setup(cvx.card, true, 1)
				print("  GHOST-ORDER %s: hand live %d, copy prints %s" % [
					cvx.card.name, cvx.live_output,
					cvx.card.describe_rich(copy.live_output)])
				copy.queue_free()
				break
		tree.quit()
		return
	# The gesture is ours now, so the targeting line and reorder can be flown end to end here.
	if "aim" in OS.get_cmdline_user_args():
		Run.hand_size_override = 5
		Router.start_combat(DB.enemies[&"cutter"], [], false)
		for iA in 60:
			await RenderingServer.frame_post_draw
		var sa := Router.current as SectorScreen
		if sa == null or sa.combat == null:
			tree.quit()
			return
		# Identity, kept for the name: events go into the game's SubViewport, so nothing converts.
		var xf := Transform2D.IDENTITY

		# --- SIDEWAYS IS A REORDER ---------------------------------------
		var first := sa.combat.hand[0]
		var second := sa.combat.hand[1]
		var v0: CardView = null
		for hv0 in sa._hand.get_children():
			var c0 := hv0 as CardView
			if c0 != null and c0.card == first:
				v0 = c0
				break
		if v0 != null:
			var f0: Vector2 = xf * (v0.global_position + v0.size * 0.5)
			await _shove(tree, f0, false, false)
			await _shove(tree, f0, true, false)
			# Sideways, staying inside the fan.
			for sx in range(1, 7):
				await _shove(tree, f0 + Vector2(float(sx) * 40.0, 0.0), true, true)
			print("  after sideways: mode %d (1 = reorder), aiming? %s"
				% [sa._grab_mode, sa._aim_view != null])
			await _shove(tree, f0 + Vector2(240.0, 0.0), false, false)
			for iR in 10:
				await RenderingServer.frame_post_draw
			print("  reorder: hand[0] was %s, is now %s ; card moved to %d"
				% [first.name, sa.combat.hand[0].name, sa.combat.hand.find(first)])

		# --- UP AND OUT IS A SHOT ----------------------------------------
		var pick: CardView = null
		for hv in sa._hand.get_children():
			var cvv := hv as CardView
			if cvv != null and cvv.card != null and cvv.card.damage > 0 \
					and sa.combat.can_play(cvv.card):
				pick = cvv
				break
		if pick == null:
			print("  no playable attack in hand")
			tree.quit()
			return
		var before_hp: int = sa.combat.enemies[0].hp
		var held := pick.card
		var from: Vector2 = xf * (pick.global_position + pick.size * 0.5)
		var slot: EnemySlot = sa.view_slot(0)
		var onto: Vector2 = xf * slot.get_global_rect().get_center()

		await _shove(tree, from, false, false)
		await _shove(tree, from, true, false)
		print("  press alone: mode %d, aiming? %s  (both must be idle)"
			% [sa._grab_mode, sa._aim_view != null])
		# Straight up, which is the shot gesture.
		await _shove(tree, from + Vector2(0, -40), true, true)
		print("  after UP: mode %d (2 = aim), armed? %s"
			% [sa._grab_mode, sa._aim_view != null])
		for st in range(1, 9):
			await _shove(tree, from.lerp(onto, float(st) / 8.0), true, true)
			await RenderingServer.frame_post_draw
		for iA2 in 10:
			await RenderingServer.frame_post_draw
		print("  target lit? %s ; reads \"%s\"" % [slot._hot, slot._drag_text])
		_snap(tree, "user://aim_line.png")
		await _shove(tree, onto, false, false)
		for iA3 in 12:
			await RenderingServer.frame_post_draw
		print("  released on the enemy: hp %d -> %d ; armed? %s ; in hand? %s"
			% [before_hp, sa.combat.enemies[0].hp, sa._aim_view != null,
				sa.combat.hand.has(held)])

		# --- CANCEL, which Godot used to provide for nothing --------------
		var pick2: CardView = null
		for hv2 in sa._hand.get_children():
			var cv2 := hv2 as CardView
			if cv2 != null and cv2.card != null and sa.combat.can_play(cv2.card):
				pick2 = cv2
				break
		if pick2 != null:
			var held2 := pick2.card
			var f2: Vector2 = xf * (pick2.global_position + pick2.size * 0.5)
			await _shove(tree, f2, false, false)
			await _shove(tree, f2, true, false)
			await _shove(tree, f2 + Vector2(0, -60), true, true)
			await _shove(tree, f2, true, true)
			await _shove(tree, f2, false, false)
			for iA4 in 12:
				await RenderingServer.frame_post_draw
			print("  cancelled back over the hand: in hand? %s ; armed? %s ; lifted? %s"
				% [sa.combat.hand.has(held2), sa._aim_view != null, pick2.armed])
		tree.quit()
		return
	if "status" in OS.get_cmdline_user_args():
		Run.hand_size_override = 5
		# Hull size sets readout placement: leviathan shows it, the cutter hides it.
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
			# The bar must not move: statuses come and go each turn and it must not shift.
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
			# The row must fit under the ship: icons replaced words wider than the hull.
			print("  AFTER  plate y %.0f h %.0f ; bar local y %.0f"
				% [ss._self_plate.position.y, ss._self_plate.size.y,
					ss._self_bar.position.y])
			print("  hull bar y %.0f before, %.0f with 7 statuses  (must match)"
				% [bar_before, ss._self_bar.global_position.y])
			print("  status row %.0f wide, %d chips"
				% [ss._player_chips.size.x, ss._player_chips.get_child_count()])
			var sv := ss._view.ship_view()
			# Ruled: leave readouts on their own rules; yours hugging your ship reads as its own.
			# Swapping your hull is the case that would separate them.
			# Why: docs/why/SectorShot.md#readout-placement
			print("  your name y %.0f ; their name y %.0f"
				% [ss._self_name.global_position.y,
					ss.view_slot(0)._name.global_position.y])
			print("  hull centre x %.0f ; plate centre x %.0f  (must match)"
				% [sv.position.x + sv.size.x * 0.5 + sv.ship_offset_x(),
					ss._self_plate.position.x + ss._self_plate.size.x * 0.5])
			print("  hull bottom y %.0f ; plate top y %.0f"
				% [sv.position.y + sv.size.y * 0.5 + sv.ship_bottom_y(),
					ss._self_plate.position.y])
		# Drift sampled over time: a drifting plate means `ship_bottom_y` stopped subtracting.
		if ss != null:
			var svb := ss._view.ship_view()
			var slb: EnemySlot = ss.view_slot(0)
			var you: Array[int] = []
			var them: Array[float] = []
			var plate: Array[float] = []
			# 240 frames for a four second cycle: 40 frames read 2..2, a still ship.
			# Why: docs/why/SectorShot.md#drift-sampling
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
		_snap(tree, "user://sector_status.png")

		# Every glyph at once: a fight shows few, and an unlooked-at icon is an unchecked one.
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
		_snap(tree, "user://status_sheet.png")
		tree.quit()
		return
	if "entrance" in OS.get_cmdline_user_args():
		Run.hand_size_override = 5
		Router.start_combat(DB.enemies[&"cutter"], [], false)
		var se := Router.current as SectorScreen
		# Early sample matters: 30 frames of a 33 frame run cannot tell a glide from a snap.
		# Why: docs/why/SectorShot.md#glide-sampling
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
		# The reticle reads a rect that changed meaning: the boxes must match once the ship lands.
		if sl0 != null:
			sl0.set_hot(true)
			for ic in 3:
				await RenderingServer.frame_post_draw
			print("  art in slot %s ; holder %s  (must match)"
				% [sl0.art.get_global_rect(), sl0.holder_rect()])
			_snap(tree, "user://sector_reticle.png")
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
			# Nineteen cards so the flow wraps and scrolls: a one-card discard cannot fail.
			# Why: docs/why/SectorShot.md#discard-pile
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
		_snap(tree, "user://sector_pile.png")
		tree.quit()
		return
	if "combat" in OS.get_cmdline_user_args():
		Run.hand_size_override = 5
		Router.start_combat(DB.enemies[&"cutter"], [], false)
		for i6 in 100:
			await RenderingServer.frame_post_draw
		var sc := Router.current as SectorScreen
		# The hail gate both ways: bracing leaves it open, shooting closes it.
		if sc != null and sc.combat != null:
			var c0 := sc.combat
			print("  hail before anything: %s (%s)"
				% [c0.can_hail(), c0.hail_reason()])
			c0.block += 5
			print("  hail after bracing:   %s (%s)"
				% [c0.can_hail(), c0.hail_reason()])
			print("  flee before anything: %s (%s)"
				% [c0.can_flee(), c0.flee_reason()])
			c0.hail_failed = true
			print("  hail after a refusal: %s (%s)"
				% [c0.can_hail(), c0.hail_reason()])
			c0.hail_failed = false
			c0.flee_failed = true
			print("  flee after a miss:    %s (%s)"
				% [c0.can_flee(), c0.flee_reason()])
			c0.flee_failed = false
			c0.damage_enemy(1, 1, "probe")
			print("  hail after a shot:    %s (%s)"
				% [c0.can_hail(), c0.hail_reason()])
			print("  flee after a shot:    %s (%s)   <- shooting must NOT block it"
				% [c0.can_flee(), c0.flee_reason()])
		# The exit panel exists only between press and answer, so the handler is called directly.
		if sc != null and ("askhail" in OS.get_cmdline_user_args()
				or "askflee" in OS.get_cmdline_user_args()):
			if "askhail" in OS.get_cmdline_user_args():
				# The probe above fired a shot, shutting hailing: refusal read as a missing panel.
				sc.combat.struck = false
				sc._on_hail()
			else:
				sc._on_flee()
			for iA2 in 6:
				await RenderingServer.frame_post_draw
			print("  panel up: %s  box %.0fx%.0f"
				% [sc._exit_ask != null, sc._exit_ask.size.x,
					sc._exit_ask.size.y])
			# AND THEN PRESS IT. The panel now holds the answer as well as the
			# question, and the answer is the half no still frame reached.
			if "resolve" in OS.get_cmdline_user_args():
				for bb in _buttons(sc._exit_ask):
					if bb.text in ["HAIL THEM", "BREAK CONTACT"]:
						bb.pressed.emit()
						break
				for iA3 in 6:
					await RenderingServer.frame_post_draw
				var said := "<none>"
				if sc._exit_box != null and sc._exit_box.get_child_count() > 0:
					said = (sc._exit_box.get_child(0) as Label).text
				print("  after: %-12s finished=%-5s box %.0fx%.0f"
					% [said, sc.combat.finished, sc._exit_ask.size.x,
						sc._exit_ask.size.y])
			_snap(tree, "user://ask.png")
			tree.quit()
			return
		if sc != null:
			# A full discard was the broken state: its back cards painted across FLEE.
			sc._discard_pile.set_count(9, "DISCARD")
			sc._draw_pile.set_count(14, "DRAW")
			for i7 in 4:
				await RenderingServer.frame_post_draw
		if sc != null:
			print("  hand band: %.0f  drawer band: %.0f  (DRAWER_H %d)"
				% [sc._hand_wrap.size.y, sc._quiet_wrap.size.y, SectorScreen.DRAWER_H])
			# Each rail measured: stylebox padding can push a button past its minimum.
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
			# Read the card's baseline: `_ready` ran before positioning so hover returned to y=0.
			# Why: docs/why/SectorShot.md#card-positions
			print("    card base_y %.0f (rest y %.0f)"
				% [(sc._hand.get_child(0) as CardView)._base_y,
					(sc._hand.get_child(0) as Control).position.y])
			# In row coordinates, the only frame the pile labels share.
			var pv: Control = sc._draw_pile
			# A hovered card's top edge is the line ENERGY and END TURN square up to.
			# Why: docs/why/SectorShot.md#card-positions
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
		_snap(tree, "user://sector_combat.png")
		tree.quit()
		return
	# `open=` and `take=` are gone: options are taken on the sector map, see `sheet=SystemShot`.
	for a2 in OS.get_cmdline_user_args():
		if (a2 as String).begins_with("open=") or (a2 as String).begins_with("take="):
			print("  %s: LOCAL no longer opens options; see sheet=SystemShot" % a2)
	# Two lit cards would mean a hover never left, which a still frame cannot tell from a cursor.
	var seen: Array = []
	_cards(Router.current, seen)
	for sc0 in seen:
		var oc := sc0 as EncounterDrawer.OptionCard
		print("  card live=%s" % oc.live)
	# `pays_item` and `jetsam_left` disagreeing would look like a payout that never happened.
	var nR: MapGen.MapNode = Run.node_at()
	if nR != null:
		print("  sector loot left: %d" % Run.jetsam_left(nR, Run.sector_jetsam(nR, false)))
	var sc2 := Router.current as SectorScreen
	if sc2 != null:
		print("  drawer band: %.0f  hand band: %.0f  (DRAWER_H %d)"
			% [sc2._quiet_wrap.size.y, sc2._hand_wrap.size.y, SectorScreen.DRAWER_H])
	_snap(tree, "user://sector%s.png" % tag)
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
		# A group needs two members rolled: a box round a single row is not ruling 1.
		var seen: Dictionary = {}
		for id in t.options:
			var g := StringName(OptionTable.by_id(id).get("group", &""))
			if g == &"":
				continue
			if seen.has(g):
				return t.index
			seen[g] = true
	return -1


## One mouse event in the game's 960x540 space, pushed into its SubViewport, no conversion.
func _shove(tree: SceneTree, at: Vector2, down: bool, move: bool) -> void:
	if move:
		var mm := InputEventMouseMotion.new()
		mm.position = at
		mm.global_position = at
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		GameShell.input_target(tree).push_input(mm)
	else:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = down
		mb.position = at
		mb.global_position = at
		mb.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		GameShell.input_target(tree).push_input(mb)
	await tree.process_frame
