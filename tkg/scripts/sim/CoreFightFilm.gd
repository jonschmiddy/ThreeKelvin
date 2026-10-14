extends Node

## THE CORE'S HOLE WHERE JON WILL SEE IT, in one look (`LocalSky.core_look`),
## filmed with its sound:
##   godot --path . --resolution 1920x1080 --write-movie <dir>/f.png --fixed-fps 60
##       -- sheet=CoreFightFilm look=<a|b|c> out=<dir>
## LOCAL at the core with your ship (the Custodian is not on LOCAL before you
## ENGAGE: the core draws no place picture and its encounter stands nothing
## there); ENGAGE (`Router.engage_here`), the Custodian's fight as the game opens
## it, its fly-in and a held look; the kill, played through `Combat.play` with
## its hull cut to one; its death; the fight ending into LOCAL, its body there.
## Prints `mark <name> <frame>` for each (frames drawn, which the movie writer
## numbers its pictures by), and once the fight is up writes `<out>/ink.png` and
## `<out>/ink.json`: the Custodian's picture as its slot draws it and where
## (game frame px), and the hole's centre and shadow radius, for the overlap.
## Every clock is the game's, your hull's bob too (`ShipView.shot_clock`).

var _t := 0.0


func _mark(name: String) -> void:
	print("mark %s %d" % [name, Engine.get_frames_drawn()])


func _wait(s: float) -> void:
	var end := _t + s
	while _t < end:
		await get_tree().process_frame


func _process(delta: float) -> void:
	_t += delta
	ShipView.shot_clock = _t


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("look="):
			LocalSky.core_look = StringName(a.substr(5))
		elif a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.CORE:
			Run.at = n.index
	SectorScreen._approached_at = Run.at
	Router.show_local()
	await _wait(2.0)
	_mark("local")
	await _wait(1.0)
	Router.engage_here()
	await _wait(2.4)
	var sc := Router.current as SectorScreen
	var cb: Combat = Router.combat
	if sc == null or cb == null or sc._view.slot(0) == null:
		print("corefightfilm: no fight")
		tree.quit()
		return
	_mark("fight")
	var slot: EnemySlot = sc._view.slot(0)
	var art: EnemyArt = slot.art
	var canvas := (art.get_global_rect().position + (art.size - Vector2(EnemyArt.W, EnemyArt.H)) * 0.5).round()
	art.snapshot().save_png(out.path_join("ink.png"))
	var sky: LocalSky = sc._view.backdrop
	var f := FileAccess.open(out.path_join("ink.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({look = String(LocalSky.core_look), canvas = [canvas.x, canvas.y],
		bob = art.position.y - slot._art_base.y, hole = [sky.origin().x, sky.origin().y],
		shadow_r = sky.core_shadow_r(), disc_r = 116.0 * sky.star_k()}))
	f.close()
	await _wait(1.6)
	# the kill
	var e: Combat.EnemyState = cb.enemies[0]
	var tries := 0
	while not cb.finished and tries < 12:
		tries += 1
		Run.hp = Run.max_hp()
		e.hp = mini(e.hp, 1)
		e.block = 0
		e.brace = 0
		var played := false
		for i in cb.hand.size():
			if cb.can_play(cb.hand[i]) and cb.hand[i].damage > 0:
				if tries == 1:
					_mark("kill")
				cb.play(i, 0)
				played = true
				break
		if not played and not cb.finished:
			cb.end_turn()
		await _wait(1.2)
	var guard := 0.0
	while Router.combat != null and guard < 12.0:
		guard += 1.0 / 60.0
		await tree.process_frame
	_mark("ended")
	await _wait(1.5)
	_mark("body")
	await _wait(2.0)
	_mark("end")
	tree.quit()


func _ready() -> void:
	_run.call_deferred()
