extends RefCounted

## Not `--headless`: the dummy display never emits `frame_post_draw`, so it hangs silently.
## Exists because the deepest hold (the heavy's 6x5) decides whether the refit layout fits.
## Why: docs/why/ShipShot.md#shot-purpose

const WEIGHTS := {
	"light": HullData.Weight.LIGHT,
	"medium": HullData.Weight.MEDIUM,
	"heavy": HullData.Weight.HEAVY,
}


func run(tree: SceneTree) -> void:
	# One frame first: Main is still in `_ready()` and cannot take children, as ConvoyTest records.
	await tree.process_frame
	var argv := OS.get_cmdline_user_args()
	var want: Array = []
	if "all" in argv:
		want = ["light", "medium", "heavy"]
	else:
		for w in WEIGHTS:
			if w in argv:
				want = [w]
				break
		# The heavy by default. A tool whose job is the tight case should not
		# need to be told which one that is.
		if want.is_empty():
			want = ["heavy"]

	for name in want:
		await _shot(tree, name)
	tree.quit()


func _shot(tree: SceneTree, weight_name: String) -> void:
	Run.start_new_run(&"korvan", int(WEIGHTS[weight_name]))
	# `sets=N` bolts on the hull manufacturer's parts: chips appear at three, a fresh run has two.
	for a in OS.get_cmdline_user_args():
		if not (a as String).begins_with("sets="):
			continue
		var fitted := 0
		var want2 := int((a as String).substr(5))
		for mid in DB.modules:
			if fitted >= want2:
				break
			var md: ModuleData = DB.modules[mid]
			if md.manufacturer != Run.hull.manufacturer:
				continue
			Run.install_module(md.duplicate(true) as ModuleData)
			fitted += 1
		print("  %d fitted · set count %d" % [fitted,
			Run.manufacturer_count(Run.hull.manufacturer)])
	# `fit=` bolts on one named part, as `-- ship` takes, so a live state can be photographed.
	for a3 in OS.get_cmdline_user_args():
		if not (a3 as String).begins_with("fit="):
			continue
		var pid := StringName((a3 as String).substr(4))
		if not DB.modules.has(pid):
			print("  no module '%s'" % pid)
			continue
		Run.install_module((DB.modules[pid] as ModuleData).duplicate(true) as ModuleData)

	# `strip` is the dragged-everything-into-the-hold state, which showed a stray set chip.
	if "strip" in OS.get_cmdline_user_args():
		Run.installed.clear()
		print("  stripped · set count %d · installed %d" % [
			Run.manufacturer_count(Run.hull.manufacturer), Run.installed.size()])

	# `mixed` is the only way to photograph the chip's greyed state.
	if "mixed" in OS.get_cmdline_user_args():
		var others := 0
		for oid in DB.manufacturers:
			if oid == Run.hull.manufacturer or others >= 3:
				continue
			for mid2 in DB.modules:
				var md2: ModuleData = DB.modules[mid2]
				if md2.manufacturer != oid:
					continue
				Run.install_module(md2.duplicate(true) as ModuleData)
				others += 1
				break
		var tally := PackedStringArray()
		for oid2 in DB.manufacturers:
			var n2 := Run.manufacturer_count(oid2)
			if n2 > 0:
				tally.append("%s %d" % [DB.short_name(DB.manufacturer_name(oid2)), n2])
		print("  mixed · %s" % ", ".join(tally))
	# `cargo` fills the hold with materials, so the crate art is judged across its whole range.
	if "cargo" in OS.get_cmdline_user_args():
		var want := ["1x1", "2x1", "2x2", "3x1", "4x1"]
		var tiers: Array[StringName] = [&"common", &"rare", &"epic",
			&"legendary", &"exotic", &"artifact", &"contraband"]
		var ti := 0
		for shape in want:
			for row in MaterialTable.all():
				if String(row.get("cells", "")) != shape:
					continue
				var m := MaterialData.of(row)
				m.tier = tiers[ti % tiers.size()]
				ti += 1
				if not Run.place_in_hold(m):
					print("  no room for %s %s" % [m.id, shape])
				break
		print("  hold %dx%d, %d items" % [Run.hull.hold_grid.x,
			Run.hull.hold_grid.y, Run.cargo.size()])
	# `stock` packs modules: their plates carry rarity edge, manufacturer stripe, silhouette.
	if "stock" in OS.get_cmdline_user_args():
		var tries := 0
		while not Run.hold_full() and tries < 40:
			tries += 1
			Run.place_in_hold(LootGen.roll_module(3 + (tries % 5), &"", true))
		print("  stock: %d modules, %d of %d cells" % [Run.cargo.size(),
			Run.cargo_used(), Run.cargo_slots()])

	# `dross` photographs a ship with something wrong, a state no fresh run is in.
	if "dross" in OS.get_cmdline_user_args():
		Run.add_dross(3)
		print("  dross: %d in the deck" % Run.dross_count())

	# `moved` photographs the moment after a hull swap, unreachable quickly by clicking.
	# Built by flying a heavy into a light, so the squeeze is real arithmetic, not a fixture.
	# Why: docs/why/ShipShot.md#moved-shot
	if "moved" in OS.get_cmdline_user_args():
		var target := Run.hull
		Run.start_new_run(&"korvan", int(HullData.Weight.HEAVY))
		for i in 6:
			Run.place_in_hold(LootGen.roll_module(3 + i, &"", true))
		Run.transfer_to_hull(target)
		print("  moved: %d stowed, %d on the pad, deck %d" % [Run.cargo.size(),
			Run.pad.size(), Run.deck_size()])
	# `name=` photographs a named ship, the state the masthead rearranges for.
	for a2 in OS.get_cmdline_user_args():
		if (a2 as String).begins_with("name="):
			Run.ship_name = (a2 as String).substr(5)
			print("  named '%s'" % Run.ship_name)
	# `tips` prints the chip tooltips: a screenshot cannot show one, so ask for the wording.
	if "tips" in OS.get_cmdline_user_args():
		for oid in DB.manufacturers:
			var n := Run.manufacturer_count(oid)
			if n < 1:
				continue
			var f := 0
			for inst in Run.installed:
				if inst.manufacturer == oid:
					f += 1
			print("--- chip hover ---
%s" % Widgets.set_tip(oid, n, f))

	Router.show_ship()
	# Waits for the animation, not a frame count: a fixed 200 took five minutes headless.
	# The frame cap stays as a stop, not as the measure.
	# Why: docs/why/ShipShot.md#settle-wait
	var t0 := Time.get_ticks_msec()
	for i in 400:
		await RenderingServer.frame_post_draw
		if Time.get_ticks_msec() - t0 > 1200:
			break
	# `rename` photographs the dialog, built fresh each open, so constructing it is a real test.
	if "rename" in OS.get_cmdline_user_args():
		var sc := Router.current as ShipScreen
		if sc != null:
			sc._open_rename()
			for i in 20:
				await RenderingServer.frame_post_draw
			print("  rename dialog open")

	# Builds the panel directly: warping the mouse never synthesises the motion tooltips need.
	# Why: docs/why/ShipShot.md#tip-panel
	if "tippanel" in OS.get_cmdline_user_args():
		var sc3 := Router.current as ShipScreen
		if sc3 != null:
			for oid in DB.manufacturers:
				var n := Run.manufacturer_count(oid)
				if n < 1:
					continue
				var f := 0
				for inst in Run.installed:
					if inst.manufacturer == oid:
						f += 1
				var plate := PanelContainer.new()
				plate.add_theme_stylebox_override("panel",
					UITheme.bevel(UITheme.PANEL2, 6, 8))
				plate.add_child(Widgets.set_readout(oid, n, f))
				plate.position = Vector2(250, 150 + 130 * sc3.get_child_count())
				plate.set_as_top_level(true)
				sc3.add_child(plate)
			for i in 6:
				await RenderingServer.frame_post_draw

	# `zoom` and `turn` photograph states needing a mouse or a part state a fresh run never makes.
	# Why: docs/why/ShipShot.md#zoom-and-turn-shots
	if "turn" in OS.get_cmdline_user_args():
		for i in Run.installed.size():
			Run.installed[i].turned = true
			Run.installed[i].flipped = i % 2 == 1
		Router.show_ship()
		var t1 := Time.get_ticks_msec()
		for i in 400:
			await RenderingServer.frame_post_draw
			if Time.get_ticks_msec() - t1 > 1200:
				break

	var zoomed := "zoom" in OS.get_cmdline_user_args()
	if zoomed and Router.current is ShipScreen:
		(Router.current as ShipScreen)._set_zoom(true)
		for i in 10:
			await RenderingServer.frame_post_draw
	var turned_shot := "turn" in OS.get_cmdline_user_args()
	var path := "user://ship_%s%s%s.png" % [weight_name,
		"_turn" if turned_shot else "", "_zoom" if zoomed else ""]
	# Position-keyed tooltip: an unreached hook looks exactly like one that returns nothing.
	var sh := Router.current as ShipScreen
	if sh != null and sh._mountpts != null:
		var mp := sh._mountpts
		print("  mounts filter %d, spots %d" % [mp.mouse_filter, mp._spots.size()])
		var asked := 0
		var answered := 0
		for i in mp._spots.size():
			var held: ModuleData = mp._spots[i].held
			if held == null:
				continue
			asked += 1
			var at: Vector2 = mp._spots[i].at
			if mp._get_tooltip(at) != "":
				answered += 1
		print("  %d of %d mounted parts answer a tooltip" % [answered, asked])
		# And the panel builds: a tooltip that throws while drawing is the same failure as none.
		var built := 0
		for i2 in mp._spots.size():
			var h2: ModuleData = mp._spots[i2].held
			if h2 == null:
				continue
			var pnl := Widgets.module_tip_panel(h2)
			if pnl != null:
				built += 1
				pnl.queue_free()
		print("  %d of %d build a tooltip panel" % [built, asked])
	tree.root.get_texture().get_image().save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))
