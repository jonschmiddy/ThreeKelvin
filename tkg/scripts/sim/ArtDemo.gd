extends RefCounted

## A looking tool, not a test: it fits the drawn parts so art can be judged on the ship.
## Why: docs/why/ArtDemo.md#looking-tool

## Shared with `Database.module_sprite` by convention, not import, so a dev tool never pins it.
const ART_DIR := "res://art/sprites/modules/"


func run(tree: SceneTree) -> void:
	await tree.process_frame
	# A heavy at S tier is the tight case, with the longest hull and most mounts.
	var argv := OS.get_cmdline_user_args()
	var weight := HullData.Weight.MEDIUM
	if "light" in argv:
		weight = HullData.Weight.LIGHT
	elif "heavy" in argv:
		weight = HullData.Weight.HEAVY
	Run.start_new_run(&"korvan", int(weight))
	for i in HullData.TIER_NAMES.size():
		if str(HullData.TIER_NAMES[i]).to_lower() in argv:
			Run.hull = DB.at_tier(DB.hull_for(&"korvan", weight) as HullData, i)
			break

	# Most cells first, as the hold packs, so a big part does not lose its mount to a small one.
	var drawn: Array[ModuleData] = []
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		if m.sprite != null:
			drawn.append(m)
	drawn.sort_custom(func(a: ModuleData, b: ModuleData) -> bool:
		return a.cells() > b.cells())

	if drawn.is_empty():
		print("no module sprites in ", ART_DIR, " — nothing to look at")
		tree.quit()
		return

	# Cleared first: `install_module` scraps the cheapest part and would drop what is being shown.
	Run.installed.clear()
	# The reactor is opened because `install_module` shuts parts down, reading as a broken sprite.
	# Why: docs/why/ArtDemo.md#reactor-opened
	Run.hull.reactor = 999
	var fitted := 0
	for m in drawn:
		if Run.slots_used(m.slot) >= Run.slots_for(m.slot):
			continue
		Run.install_module(m.duplicate(true) as ModuleData)
		fitted += 1
	# `full` fills the rest, as four drawn parts cannot fill a nine-mount hull's loadout column.
	if "full" in argv:
		for id2 in DB.modules:
			var m2: ModuleData = DB.modules[id2]
			if Run.slots_used(m2.slot) >= Run.slots_for(m2.slot):
				continue
			Run.install_module(m2.duplicate(true) as ModuleData)
			fitted += 1

	print("\n=== ART DEMO ===")
	for m in Run.installed:
		# `-- artdemo full` fits parts that have no art, on purpose, so the
		# listing can no longer assume a sprite is there to measure.
		var art := "no sprite"
		if m.sprite != null:
			art = "sprite %dx%d" % [m.sprite.get_width(), m.sprite.get_height()]
		print("  %-12s %-22s %dx%d cells   %s"
			% [ModuleData.slot_name(m.slot), m.name, maxi(1, m.size.x),
				maxi(1, m.size.y), art])
	var carded := 0
	for m in Run.installed:
		for c in m.cards:
			if DB.card_art(c.art_key()) != null:
				carded += 1
	# A part missing for lack of mounts is expected, so it is said, or the question lingers.
	for m in drawn:
		var on := false
		for x in Run.installed:
			if x.id == m.id:
				on = true
		if not on:
			var why := "no free %s mount" % ModuleData.slot_name(m.slot)
			if Run.slots_used(m.slot) < Run.slots_for(m.slot):
				why = "displaced — reactor or hold, not mounts"
			print("  not fitted: %-22s %s (%d of %d %s mounts used)"
				% [m.name, why, Run.slots_used(m.slot), Run.slots_for(m.slot),
					ModuleData.slot_name(m.slot)])
	print("  %d parts fitted, %d of their cards have art" % [fitted, carded])
	print("  ZOOM button over the hull · drag to pan · hover the right panel\n")

	# `turn` stows parts in cargo, as repacking `Run.installed` changed nothing on screen.
	# Why: docs/why/ArtDemo.md#turned-parts
	if "turn" in argv or "hold" in argv:
		var stood := 0
		for m in drawn:
			var copy := m.duplicate(true) as ModuleData
			# Square asks for nothing -- a 2x2 turned is the same 2x2.
			if "turn" in argv and copy.size.x != copy.size.y:
				copy.turned = true
				stood += 1
			if not Run.stow(copy):
				print("  no hold room for %s" % copy.name)
		Run.repack_hold()
		print("  stowed %d parts, %d stood on end\n"
			% [Run.cargo.size(), stood])

	Sig.ship_changed.emit()
	# `sector` arrives via another screen; kept though the slide was a stale pan flag.
	# Why: docs/why/ArtDemo.md#arrive-by-sector
	if "sector" in argv:
		Router.show_sector()
		for i in 40:
			await RenderingServer.frame_post_draw

	Router.show_ship()


	# `shot` photographs it, as `-- shipshot` shows the starter ship with none of the drawn parts.
	# Why: docs/why/ArtDemo.md#shot-mode
	if "zoom" in OS.get_cmdline_user_args() and Router.current is ShipScreen:
		for i in 30:
			await RenderingServer.frame_post_draw
		var sc := Router.current as ShipScreen
		sc._set_zoom(true)
		for i in 30:
			await RenderingServer.frame_post_draw
		# `front` drags the view as far as a player can, to show the nose and longest gun reach.
		if "front" in OS.get_cmdline_user_args():
			var slack: float = maxf((sc._view.size.x - sc._clip.size.x) * 0.5, 0.0)
			sc._pan.x = -(slack + sc._bleed())
			sc._sync_clip()
			for i in 20:
				await RenderingServer.frame_post_draw

	if not ("shot" in OS.get_cmdline_user_args()):
		return
	var t0 := Time.get_ticks_msec()
	for i in 400:
		await RenderingServer.frame_post_draw
		if Time.get_ticks_msec() - t0 > 1500:
			break
	var path := "user://artdemo.png"
	tree.root.get_texture().get_image().save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))
	tree.quit()
