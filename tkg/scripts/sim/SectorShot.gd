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
	var target := _find(want_group)
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
