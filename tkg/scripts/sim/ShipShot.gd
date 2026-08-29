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
	tree.root.get_texture().get_image().save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))
