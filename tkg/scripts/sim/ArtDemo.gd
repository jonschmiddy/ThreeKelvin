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
	# `-- artdemo full` FILLS THE REST WITH WHATEVER EXISTS. The drawn parts
	# cannot fill a nine-mount hull -- there are four of them -- and a loadout
	# column with four entries is not the column a real ship has. The report
	# came off a full one, and the width of that column is exactly what is
	# under suspicion here.
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

	# `-- artdemo turn` STANDS EVERY LONG PART ON END IN THE HOLD, which is the
	# only place a part can be turned at all: `turned` is a PACKING decision and
	# the hull's mounts never see it. So fitting the drawn parts is not enough to
	# reach the case -- they have to be STOWED, which is why this puts a copy of
	# each into cargo rather than turning what is already bolted on. Turning
	# `Run.installed` and repacking looked right, printed "stood 3 parts on end",
	# and changed nothing on screen, because repack_hold walks `Run.cargo`.
	#
	# The bug it exists to show: a turned part keeps its footprint and swaps its
	# axes, and for a while the ART did not swap with it -- a stood-up gun kept
	# drawing lengthwise and ran straight through both its neighbours.
	#
	# `-- artdemo hold` stows them without turning, which is the before picture.
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
	# `-- artdemo sector` ARRIVES BY WAY OF ANOTHER SCREEN, because a screen that
	# replaces one already up is not the same screen as one built into an empty
	# root -- the outgoing one is still holding its size while the incoming one
	# asks for its own, and anything measured during that is measured early.
	#
	# Added chasing a report that the ship slid sideways when a part moved in
	# the hold, on the theory that arriving from the sector left the hull view
	# placed against a stale width. IT DID NOT: the clip measured 431 on every
	# frame from the first, and the real cause was a pan flag left set by an
	# earlier press. Kept anyway -- arriving the way a player arrives is worth
	# being able to do, and the next layout bug will want it.
	if "sector" in argv:
		Router.show_sector()
		for i in 40:
			await RenderingServer.frame_post_draw

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
