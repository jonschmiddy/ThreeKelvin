extends RefCounted

## Does the ship move when you change its loadout?
##   godot --headless --path . -- shipdrift
##
## IT SHOULD NOT. Where the hull sits in its window is a fact about the hull and
## the window. Bolting a gun on may add a gun; it may not slide the ship.
##
## Reported twice. The first report blamed moving a part in the hold and the
## cause was a stuck pan flag, fixed in `_on_clip_input`. The second blamed
## unmounting a module, and this is a different fault with the same symptom:
## `ShipView.ship_offset_x()` measures `_img.get_used_rect()`, the bounding box
## of everything DRAWN -- and `_draw_modules` draws the fitted parts into that
## same image. So the box moves with the loadout, `ShipScreen._ship_x()`
## subtracts the offset, and the hull slides.
##
## Headless is fine: this measures the composited image, not a rendered frame.

func run(tree: SceneTree) -> void:
	await tree.process_frame
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))

	var view := ShipView.new()
	tree.root.add_child(view)
	view.magnify(1, 0)
	await tree.process_frame

	var build := ShipBuild.local()
	var fitted: Array = []
	for p in build.parts:
		fitted.append(p)
	if fitted.is_empty():
		print("shipdrift: SKIP -- the starter ship has no fitted modules")
		tree.quit()
		return

	view.refresh()
	await tree.process_frame
	var full: float = view.ship_offset_x()

	# Take one module off and ask again. Nothing about the hull changed.
	var removed: Variant = fitted[fitted.size() - 1]
	build.parts.erase(removed)
	view.refresh()
	await tree.process_frame
	var stripped: float = view.ship_offset_x()

	build.parts.append(removed)
	view.refresh()
	await tree.process_frame
	var restored: float = view.ship_offset_x()
	view.queue_free()

	# AND THE REAL SCREEN, which is where it was reported. `ship_offset_x` is
	# only one of three inputs to `ShipScreen._ship_x()`, and it is the one that
	# turned out to be stable -- so measure what the eye actually sees: where the
	# view gets placed inside its window.
	var screen := ShipScreen.new()
	tree.root.add_child(screen)
	screen.setup()
	for i in 6:
		await tree.process_frame
	screen._sync_clip()
	await tree.process_frame
	var x0: float = screen._view.position.x
	var p0: float = screen._pan.x

	var b2 := ShipBuild.local()
	var take: Variant = b2.parts[b2.parts.size() - 1]
	b2.parts.erase(take)
	screen._sync_clip()
	await tree.process_frame
	var x1: float = screen._view.position.x
	var p1: float = screen._pan.x
	print("  screen: view.x %.1f -> %.1f   (pan.x %.1f -> %.1f)" % [x0, x1, p0, p1])
	print("  clip %.0f wide - view %.0f wide - ship_x %.1f - bleed %.1f" % [
		screen._clip.size.x, screen._view.size.x, screen._ship_x(), screen._bleed()])
	# AND IT MUST BE CENTRED, not merely stable. A ship narrower than its window
	# has nowhere to pan to, so a non-zero pan at 1x is the bug even when it is
	# not currently moving.
	if absf(p1) >= 0.5 and screen._view.size.x <= screen._clip.size.x:
		print("  FAIL pan.x is %.1f with the ship fitting its window" % p1)
	elif absf(x1 - x0) >= 0.5:
		print("  FAIL the ship moved %.1f px when a module came off" % (x1 - x0))
	else:
		print("  ok   the ship held position on the real screen")

	print("\n=== SHIP DRIFT ===")
	print("  %d modules fitted" % fitted.size())
	print("  ship_offset_x  fitted %.2f · one removed %.2f · refitted %.2f"
		% [full, stripped, restored])
	var drift: float = absf(stripped - full)
	print("  drift when a module comes off: %.2f px" % drift)
	var ok := drift < 0.01 and absf(restored - full) < 0.01
	if ok:
		print("  ok   the hull does not move with its loadout")
		print("shipdrift: PASS")
	else:
		print("  FAIL the hull moves %.2f px when a module is unmounted" % drift)
		print("shipdrift: FAIL")
	tree.quit()
