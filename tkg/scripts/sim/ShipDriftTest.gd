extends RefCounted

## The hull must not slide on loadout change: its used rect includes the drawn modules.
## Why: docs/why/ShipDriftTest.md#ship-drift

func run(tree: SceneTree) -> void:
	await tree.process_frame
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))

	var view := ShipView.new()
	tree.root.add_child(view)
	view.magnify(1, 0)
	await tree.process_frame

	var fitted: Array = Run.installed.duplicate()
	if fitted.is_empty():
		print("shipdrift: SKIP -- the starter ship has no fitted modules")
		tree.quit()
		return

	view.refresh()
	await tree.process_frame
	var full: float = view.ship_offset_x()

	# Take one module off and ask again. Nothing about the hull changed.
	# From the run's own list and with the signal, as the view caches its build until told.
	var removed: Variant = fitted[fitted.size() - 1]
	Run.installed.erase(removed)
	Sig.ship_changed.emit()
	await tree.process_frame
	var stripped: float = view.ship_offset_x()

	Run.installed.append(removed)
	Sig.ship_changed.emit()
	await tree.process_frame
	var restored: float = view.ship_offset_x()
	view.queue_free()

	# Measures the real screen, as `ship_offset_x` is only one of three inputs.
	var screen := ShipScreen.new()
	tree.root.add_child(screen)
	screen.setup()
	for i in 6:
		await tree.process_frame
	screen._sync_clip()
	await tree.process_frame
	var x0: float = screen._view.position.x
	var p0: float = screen._pan.x

	Run.installed.erase(removed)
	Sig.ship_changed.emit()
	screen._sync_clip()
	await tree.process_frame
	var x1: float = screen._view.position.x
	var p1: float = screen._pan.x
	print("  screen: view.x %.1f -> %.1f   (pan.x %.1f -> %.1f)" % [x0, x1, p0, p1])
	print("  clip %.0f wide - view %.0f wide - ship_x %.1f - bleed %.1f" % [
		screen._clip.size.x, screen._view.size.x, screen._ship_x(), screen._bleed()])
	# Must be centred, not just stable: a narrow ship at 1x has nowhere to pan.
	var screen_ok := true
	if absf(p1) >= 0.5 and screen._view.size.x <= screen._clip.size.x:
		print("  FAIL pan.x is %.1f with the ship fitting its window" % p1)
		screen_ok = false
	elif absf(x1 - x0) >= 0.5:
		print("  FAIL the ship moved %.1f px when a module came off" % (x1 - x0))
		screen_ok = false
	else:
		print("  ok   the ship held position on the real screen")

	print("\n=== SHIP DRIFT ===")
	print("  %d modules fitted" % fitted.size())
	print("  ship_offset_x  fitted %.2f · one removed %.2f · refitted %.2f"
		% [full, stripped, restored])
	var drift: float = absf(stripped - full)
	print("  drift when a module comes off: %.2f px" % drift)
	var ok := drift < 0.01 and absf(restored - full) < 0.01 and screen_ok
	if ok:
		print("  ok   the hull does not move with its loadout")
		print("shipdrift: PASS")
	else:
		print("  FAIL the hull moves %.2f px when a module is unmounted (the screen's own check %s)" % [drift, "held" if screen_ok else "failed"])
		print("shipdrift: FAIL")
	tree.quit(0 if ok else 1)
