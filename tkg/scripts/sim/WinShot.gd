extends Node

## A FIGHT WON, filmed through the real router (alpha blocker 4: after a won
## fight you stay on LOCAL by the wrecks, where the pay is, instead of being sent
## to the map):
##   godot --path . --windowed --position 3840,0 -- sheet=WinShot keepwindow
##       clip=<dir> [seed=N] [style=...] [every=3] [after=240]
## Starts a run, opens a fight at a system the way an option's fight opens
## (shared off, not clearing the system), plays it to a win (the enemy's hull
## cut to one first, so the clip is short), and saves the game's picture every
## `every` frames from a moment before the kill to `after` frames past it. Prints
## which screen the router left you on and how many wrecks it draws. Needs a
## window.

var _args: PackedStringArray


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var idx := -1
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.SYSTEM and not n.cleared:
			idx = n.index
			break
	if idx < 0:
		print("winshot: no system to fight at")
		tree.quit()
		return
	Run.at = idx
	Run.map[idx].visited = true
	SectorScreen._approached_at = idx
	Router.show_local()
	for i in 20:
		await RenderingServer.frame_post_draw
	Run.hand_size_override = 5
	Router.start_combat(DB.enemies[&"cutter"], [], false, false)
	var dir := _arg("clip")
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	var every := int(_arg("every", "3"))
	var k := 0
	for i in 60:
		await RenderingServer.frame_post_draw
		if i % every == 0:
			k = _save(dir, k)
	var cb: Combat = Router.combat
	if cb == null:
		print("winshot: no fight opened")
		tree.quit()
		return
	# THE KILL: the enemy's hull cut to one, then the first playable card at it
	for e in cb.enemies:
		e.hp = mini(e.hp, 1)
	var tries := 0
	while not cb.finished and tries < 12:
		tries += 1
		var played := false
		for i in cb.hand.size():
			if cb.can_play(cb.hand[i]):
				cb.play(i, 0)
				played = true
				break
		if not played and not cb.finished:
			cb.end_turn()
		for f in 6:
			await RenderingServer.frame_post_draw
			k = _save(dir, k) if f % every == 0 else k
	print("winshot: fight %s after %d tries" % [cb.result, tries])
	var after := int(_arg("after", "240"))
	for i in after:
		await RenderingServer.frame_post_draw
		if i % every == 0:
			k = _save(dir, k)
	var sc := Router.current
	var wrecks := 0
	for raw in Run.node_at().jetsam:
		if (raw as MapGen.Jetsam).is_wreck():
			wrecks += 1
	print("winshot: on %s, %d wreck(s) in the system" % [sc.get_script().get_global_name() if sc != null else "nothing", wrecks])
	var outp := _arg("out")
	if outp != "":
		tree.root.get_texture().get_image().save_png(outp)
	tree.quit()


func _save(dir: String, k: int) -> int:
	if dir == "":
		return k
	get_tree().root.get_texture().get_image().save_png("%s/f_%04d.png" % [dir, k])
	return k + 1
