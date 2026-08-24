extends RefCounted

## Every part that HAS art, on one ship, live:
##   godot --path . -- artdemo
##
## A LOOKING TOOL, not a test. `-- artcheck` answers whether an asset is the
## right size and `-- shipshot` photographs one hull; neither answers the only
## question that matters while art is being made, which is whether the thing
## looks right on the ship with a hand on the mouse. A fresh run installs
## whatever the starter kit says, so most of the parts being drawn are simply
## not on screen to be judged.
##
## So this fits the drawn ones deliberately, and puts their cards in the deck.
## Zoom with the button over the hull, drag to pan, hover a module in the right
## panel to light it up on the hull, F to flip a fitted part.
##
## It reads the SAME LIST the coverage gate does — anything with a file in
## art/sprites/modules is fitted here — so a part drawn tomorrow needs no edit
## to this file to be looked at.

## Where a module's sprite lives. One string, shared with Database.module_sprite
## by convention rather than by import: this is a dev tool and must not be the
## reason a path is hard to change.
const ART_DIR := "res://art/sprites/modules/"


func run(tree: SceneTree) -> void:
	await tree.process_frame
	# WHICH SHIP TO LOOK AT:  -- artdemo heavy s
	# The tight case is not the medium. A heavy at S tier is the longest hull
	# in the game carrying the most mounts, which is where a long part runs out
	# of window first — so the thing most worth looking at has to be reachable.
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

	# THE DRAWN ONES, most cells first. Biggest parts get their pick of the
	# hardpoints, which is the same order the hold would pack them in and stops a
	# four-cell siege driver losing its mount to a one-cell scope.
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

	# Cleared first. The starter kit fills the weapon mounts, and install_module
	# scraps the cheapest part to make room — which would quietly drop the very
	# thing this tool exists to show.
	Run.installed.clear()
	# AND THE REACTOR IS OPENED UP. install_module shuts down the cheapest fitted
	# part until the new one can be powered, so five real modules on a tier-0
	# medium quietly cost you the mass driver — which reads as "the sprite is
	# broken" and is actually the ship being honest about its power budget. A
	# looking tool has no business simulating that, so it does not.
	Run.hull.reactor = 999
	var fitted := 0
	for m in drawn:
		if Run.slots_used(m.slot) >= Run.slots_for(m.slot):
			continue
		Run.install_module(m.duplicate(true) as ModuleData)
		fitted += 1

	print("\n=== ART DEMO ===")
	for m in Run.installed:
		print("  %-12s %-22s %dx%d cells   sprite %dx%d"
			% [ModuleData.slot_name(m.slot), m.name, maxi(1, m.size.x),
				maxi(1, m.size.y), m.sprite.get_width(), m.sprite.get_height()])
	var carded := 0
	for m in Run.installed:
		for c in m.cards:
			if DB.card_art(c.art_key()) != null:
				carded += 1
	# WHAT DID NOT FIT, and why. A hull has a fixed number of mounts and the drawn
	# parts can outnumber them, so a part silently missing from the ship is the
	# expected case rather than a fault -- but it has to be SAID, or the next
	# question is "where is the mass driver" with no answer on screen.
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

	Sig.ship_changed.emit()
	Router.show_ship()

	# `-- artdemo shot` PHOTOGRAPHS IT, because a looking tool nobody can
	# measure is a looking tool that gets argued about. `-- shipshot` cannot
	# serve here: it photographs the STARTER ship, which carries none of the
	# parts being drawn, so every card in its panel falls back to a glyph and
	# a reading taken off it says nothing about the art at all. That mistake
	# cost an afternoon.
	# `-- artdemo heavy s zoom shot` photographs the tight case ZOOMED, which is
	# where a long part runs out of window. Settle first: the zoom retimes the
	# clip and the mounts, and a shot taken during that is a shot of the
	# transition rather than of the result.
	if "zoom" in OS.get_cmdline_user_args() and Router.current is ShipScreen:
		for i in 30:
			await RenderingServer.frame_post_draw
		var sc := Router.current as ShipScreen
		sc._set_zoom(true)
		for i in 30:
			await RenderingServer.frame_post_draw
		# `-- artdemo heavy s zoom front shot` drags the view as far forward as
		# the pan allows. That is the state a player reaches by grabbing the ship
		# and pulling, and it is the only one that can show whether the NOSE and
		# the longest gun can actually be brought into the window.
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
