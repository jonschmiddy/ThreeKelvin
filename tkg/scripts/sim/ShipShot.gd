extends RefCounted

## The refit screen, photographed, one weight at a time.
##
##   godot --path . -- shipshot            the heavy, which is the tight one
##   godot --path . -- shipshot medium
##   godot --path . -- shipshot all        one PNG per weight
##   godot --path . -- shipshot medium turn
##
## NOT `--headless`. The settle waits on `frame_post_draw`, which the dummy
## display server never emits, so a headless run sits in that loop until it is
## killed and writes nothing. It looks exactly like a hang because it is one.
##
## WHY THIS EXISTS. The refit screen's layout is a budget between two panels: the
## masthead is as deep as the ship in it and the workbench gets what is left. The
## question every change to it asks is "does the deepest hold still fit", and the
## deepest hold belongs to the heavy — 6x5 cells against the light's 4x3. That is
## not a question you can answer by opening the screen on whatever ship a new run
## happened to roll, and it is not one a still of the wrong weight can answer at
## all.
##
## Same shape as ConvoyTest's `convoy` mode and for the same reason: it needs a
## window, it cannot assert anything, and it exists because layout questions are
## answered by looking.

const WEIGHTS := {
	"light": HullData.Weight.LIGHT,
	"medium": HullData.Weight.MEDIUM,
	"heavy": HullData.Weight.HEAVY,
}


func run(tree: SceneTree) -> void:
	# One frame before anything is added, for the reason ConvoyTest records:
	# Main is still inside _ready() and a node cannot take children while it is
	# setting up its own.
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
	# `-- shipshot heavy sets=4` bolts on that many of the hull manufacturer's own
	# parts, which is the only way to photograph the set-bonus chips in the perk
	# corner: a fresh run counts two toward a set and the chips appear at three,
	# so the state this tool built by default was the one that could not show
	# them.
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
	# `fit=plasma` bolts on one named part, repeatable. The same argument
	# `-- ship` takes, so a state reached live can be photographed without
	# rebuilding it out of `sets=` and `mixed`.
	for a3 in OS.get_cmdline_user_args():
		if not (a3 as String).begins_with("fit="):
			continue
		var pid := StringName((a3 as String).substr(4))
		if not DB.modules.has(pid):
			print("  no module '%s'" % pid)
			continue
		Run.install_module((DB.modules[pid] as ModuleData).duplicate(true) as ModuleData)

	# `strip` takes everything off the hull. The state a player reaches by
	# dragging their whole loadout into the hold, and the one that showed a set
	# chip for a manufacturer nothing was fitted from -- the hull counts toward a
	# set, so the total was 1 with an empty ship.
	if "strip" in OS.get_cmdline_user_args():
		Run.installed.clear()
		print("  stripped · set count %d · installed %d" % [
			Run.manufacturer_count(Run.hull.manufacturer), Run.installed.size()])

	# `mixed` bolts on one part each from three OTHER manufacturers, which is the
	# only way to photograph the chip's greyed state -- a run fitted from one
	# catalogue shows the earned chip and nothing else, and "greyed until it
	# lands" is the half of the design that cannot be seen that way.
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
	# `-- shipshot medium cargo` fills the hold with materials, which is the only
	# way to look at the thing materials are FOR. One of every shape and a spread
	# of tiers, so the crate art is judged across the range it has to cover
	# rather than on whichever row happened to roll.
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
	# `-- shipshot medium stock` packs the hold with MODULES rather than crates.
	# `cargo` fills it with materials, which draw as boxes; this is the other
	# half of what a hold holds, and the half whose plates carry a rarity edge, a
	# manufacturer stripe and a silhouette.
	if "stock" in OS.get_cmdline_user_args():
		var tries := 0
		while not Run.hold_full() and tries < 40:
			tries += 1
			Run.place_in_hold(LootGen.roll_module(3 + (tries % 5), &"", true))
		print("  stock: %d modules, %d of %d cells" % [Run.cargo.size(),
			Run.cargo_used(), Run.cargo_slots()])

	# `-- shipshot medium dross` photographs a ship WITH SOMETHING WRONG WITH IT,
	# which is the state the malfunction block on the loadout panel exists for
	# and one no fresh run is ever in.
	if "dross" in OS.get_cmdline_user_args():
		Run.add_dross(3)
		print("  dross: %d in the deck" % Run.dross_count())

	# `-- shipshot light moved` photographs the screen the MOMENT AFTER A HULL
	# SWAP, which is the one state the dock exists for and the only one no
	# amount of clicking reaches quickly: you have to find a yard with a smaller
	# frame on the blocks and be carrying enough to overflow it.
	#
	# Built by flying a HEAVY and moving into whatever this shot was asked for,
	# so the squeeze is real arithmetic and not a hand-placed fixture -- 30 cells
	# of loadout and hold going into a light's 12 strands about half of it.
	if "moved" in OS.get_cmdline_user_args():
		var target := Run.hull
		Run.start_new_run(&"korvan", int(HullData.Weight.HEAVY))
		for i in 6:
			Run.place_in_hold(LootGen.roll_module(3 + i, &"", true))
		Run.transfer_to_hull(target)
		print("  moved: %d stowed, %d on the pad, deck %d" % [Run.cargo.size(),
			Run.pad.size(), Run.deck_size()])
	# `name=Bad Penny` photographs a NAMED ship, which is the state the masthead
	# rearranges for -- the pilot's name takes the big line and the frame's own
	# drops beside the chassis. A shot of an unnamed one cannot show that.
	for a2 in OS.get_cmdline_user_args():
		if (a2 as String).begins_with("name="):
			Run.ship_name = (a2 as String).substr(5)
			print("  named '%s'" % Run.ship_name)
	# `tips` prints what the set chips say on hover. A tooltip is the one part of
	# a screen a screenshot cannot show, so the only way to check its wording is
	# to ask for it.
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
	# The ship flies in and the mounts settle behind it, and this waits for
	# THE ANIMATION rather than for a number of frames.
	#
	# A fixed 200 was five minutes on a machine whose headless frames run at
	# better than a second each -- the loop's job is `the arrival is over`,
	# and a frame count only means that where frames are cheap. Tweens run on
	# the same delta the frames do, so waiting on the clock finishes the
	# arrival in two slow frames or in eighty fast ones, and either is right.
	# The frame cap stays as a stop, not as the measure.
	var t0 := Time.get_ticks_msec()
	for i in 400:
		await RenderingServer.frame_post_draw
		if Time.get_ticks_msec() - t0 > 1200:
			break
	# `rename` opens the rename dialog and photographs it. A dialog is the one
	# part of a screen a still of the screen cannot show, and this one is built
	# fresh every time it opens -- so "does it construct" is a real question and
	# not a rhetorical one.
	if "rename" in OS.get_cmdline_user_args():
		var sc := Router.current as ShipScreen
		if sc != null:
			sc._open_rename()
			for i in 20:
				await RenderingServer.frame_post_draw
			print("  rename dialog open")

	# `tippanel` builds what a chip answers with and parks it on the screen.
	#
	# `hover` below warps the mouse and waits, which does NOT work: warping the
	# pointer does not synthesise the motion event Godot's GUI uses to start a
	# tooltip timer, so the shot comes back with no tooltip and no error. This
	# builds the panel directly instead and wraps it in the plate Godot would
	# have wrapped it in -- `bevel(PANEL2)`, which is what `perk_readout`'s own
	# comment records the tooltip theme using.
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

	# `-- shipshot heavy zoom` photographs the doubled view, which is the only
	# way to see it without a hand on the mouse: the zoom is a click and a
	# drag, and neither exists in a headless render.
	# `-- shipshot medium turn` PACKS EVERY PART SIDEWAYS AND FLIPS HALF OF
	# THEM, which is the only way to photograph the two states a fitted part
	# can be in that a fresh run never produces. It is a rendering question
	# and the answer is a picture, so the tool that takes the picture is the
	# one that has to be able to set it up.
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
	# CAN YOU READ WHAT IS BOLTED ON? The hull draws its parts rather than
	# holding controls for them, so the tooltip is position-keyed -- and a hook
	# that is never reached looks exactly like one that returns nothing.
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
		# AND THE PANEL BUILDS. A tooltip that names a part and then throws
		# while drawing it is the same failure as no tooltip at all -- which is
		# how this one shipped the first time.
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
