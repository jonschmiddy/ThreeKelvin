extends Node

## THE CORE'S WIN, PHOTOGRAPHED AND FILMED through the real router:
##   godot --path . --windowed --position 3840,0 --fixed-fps 30 -- sheet=CoreWinShot
##       out=<dir> [seed=N] [every=2] [style=...]
## A run with a used hold parked at the core, ENGAGE pressed, the custodian's
## hull cut to one, then the kill played; the body opens over LOCAL, two parts
## are taken out of it a second apart, DONE is pressed, and the win screen
## holds. Writes `loot.png` (the body, its scan finished), `win.png` (the win
## screen) and `clip/f_####.png` every `every` frames from the last hit to the
## popup. The clock is the game's: run with `--fixed-fps 30` and frames encoded
## at 30/every fps play at true speed. Needs a window. Audio is the Dummy
## driver, so the clip is silent; it prints the music each step asked for.

var _args: PackedStringArray
var _dir := ""
var _every := 2
var _k := 0


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _draw_frames(n: int, film: bool = true) -> void:
	for i in n:
		await RenderingServer.frame_post_draw
		if film and _dir != "" and i % _every == 0:
			get_tree().root.get_texture().get_image().save_png("%s/clip/f_%04d.png" % [_dir, _k])
			_k += 1


func _still(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	img.save_png("%s/%s" % [_dir, name])
	print("corewinshot: %s %dx%d" % [name, img.get_width(), img.get_height()])


func _run() -> void:
	var tree := get_tree()
	_dir = _arg("out")
	_every = maxi(1, int(_arg("every", "2")))
	DirAccess.make_dir_recursive_absolute(_dir + "/clip")
	await tree.process_frame
	Rng.forced = int(_arg("seed", "31337"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for i in 2:
		Run.stow(LootGen.roll_module(6))
	Run.jumps = 41
	Run.kills = 17
	var idx := -1
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.CORE:
			idx = n.index
	Run.at = idx
	Run.map[idx].visited = true
	SectorScreen._approached_at = idx
	Router.show_local()
	await _draw_frames(30, false)
	Router.engage_here()
	await _draw_frames(90, false)
	var cb: Combat = Router.combat
	if cb == null:
		print("corewinshot: no fight opened")
		tree.quit(1)
		return
	print("corewinshot: fighting %s, music asked %s" % [cb.enemies[0].template.name, Audio.music_asked])
	Run.hp = Run.max_hp()
	# the body's hull at one, so the next card is the last hit
	for e in cb.enemies:
		e.hp = 1
		e.block = 0
	await _draw_frames(20, false)
	await _draw_frames(12)
	var tries := 0
	while not cb.finished and tries < 20:
		tries += 1
		for e in cb.enemies:
			e.hp = mini(e.hp, 1)
			e.block = 0
		# an attack first, so the clip opens on the last hit
		var pick := -1
		for i in cb.hand.size():
			if not cb.can_play(cb.hand[i]):
				continue
			if pick < 0 or (cb.hand[i].damage > 0 and cb.hand[pick].damage <= 0):
				pick = i
		var played := pick >= 0
		if played:
			cb.play(pick, 0)
		if not played and not cb.finished:
			cb.end_turn()
		await _draw_frames(12)
	print("corewinshot: fight %s after %d plays" % [cb.result, tries])
	# the body opens; its scan sweep plays
	await _draw_frames(120)
	var sc := Router.current as SectorScreen
	print("corewinshot: loot step %s, popup %s, music asked %s" % [Router.final_loot,
		sc != null and sc.has_open_container(), Audio.music_asked])
	await _still("loot.png")
	# two parts taken, a second apart, as a player would drag them across
	var body := Router.core_body_here()
	var took := 0
	if body != null:
		for i in body.items.size():
			if took >= 2:
				break
			if await Run.take_from_jetsam(Run.node_at(), body, i):
				took += 1
				await _draw_frames(30)
	await _still("loot_taken.png")
	await _draw_frames(20)
	var tv: TransferView = sc._transfer if sc != null else null
	var done: Button = _find(tv, func(n: Node) -> bool:
		return n is Button and (n as Button).text == "DONE") as Button
	if done != null:
		done.pressed.emit()
	await _draw_frames(90)
	print("corewinshot: on %s, music asked %s" % [
		Router.current.get_script().get_global_name() if Router.current != null else "nothing",
		Audio.music_asked])
	await _still("win.png")
	print("corewinshot: %d clip frames" % _k)
	tree.quit()


func _find(root: Node, matches: Callable) -> Node:
	if root == null:
		return null
	if matches.call(root):
		return root
	for c in root.get_children():
		var f := _find(c, matches)
		if f != null:
			return f
	return null
