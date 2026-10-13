extends Node

## A WHOLE FIGHT, PLAYED TO ITS END, for a full-screen film with its sound:
##   godot --path . --resolution 1920x1080 --write-movie <dir>/f.png --fixed-fps 60
##       -- sheet=FightFilm id=<enemy> [hp=6] [hold=2] [seed=N]
## Godot's movie writer writes every frame of the window and the game's own mix
## (`f########.png`, `f.wav`) at true speed. The fight, on one enemy alone:
## its fly-in; a first turn of skills (nothing that hurts it), END TURN and its
## move played out; a second turn of attacks until it dies -- the killing shot,
## the death, the wreck, the hand lowering and everything easing into LOCAL --
## then `hold` seconds on LOCAL arrived. The enemy starts on `hp` hull so the
## second turn's attacks kill it; your hull is kept full. Quits at the end.

const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")

var _args: PackedStringArray


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	var id := StringName(_arg("id", "cutter"))
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.hand_size_override = 5
	for n: MapGen.MapNode in Run.map:
		if n.type != MapGen.NodeType.STATION and n.type != MapGen.NodeType.START \
				and String(SkyWeatherS.sky_of_node(n)) == "calm":
			Run.at = n.index
			break
	SectorScreen._approached_at = Run.at
	Router.start_combat(DB.enemies[id], [], false, false)
	var cb: Combat = Router.combat
	var e: Combat.EnemyState = cb.enemies[0]
	e.hp = mini(e.max_hp, int(_arg("hp", "6")))
	Sig.enemy_changed.emit()
	var sc := Router.current as SectorScreen
	await _wait(2.2)
	# turn one: skills only
	var played := 0
	for k in 3:
		var pick := -1
		for i in cb.hand.size():
			var c: CardData = cb.hand[i]
			if cb.can_play(c) and c.damage <= 0:
				pick = i
				break
		if pick < 0:
			break
		cb.play(pick, 0)
		played += 1
		await _wait(1.1)
	print("fightfilm: turn one, %d skills played" % played)
	await _wait(0.6)
	Run.hp = Run.max_hp()
	sc._on_end_turn()
	await _wait(0.5)
	while sc._playing or sc._hold:
		await tree.process_frame
	await _wait(1.0)
	# turn two (and on): attacks until it dies
	for turn in 4:
		if e.hp <= 0 or cb.finished:
			break
		for k in 6:
			if e.hp <= 0:
				break
			var pick := -1
			for i in cb.hand.size():
				var c: CardData = cb.hand[i]
				if cb.can_play(c) and c.damage > 0:
					pick = i
					break
			if pick < 0:
				break
			Run.hp = Run.max_hp()
			cb.play(pick, 0)
			await _wait(1.0)
		if e.hp > 0 and not cb.finished:
			sc._on_end_turn()
			await _wait(0.5)
			while sc._playing or sc._hold:
				await tree.process_frame
			await _wait(0.8)
	print("fightfilm: %s dead %s, fight %s" % [id, str(e.hp <= 0), cb.result])
	# the death, the wreck, the hand lowering, LOCAL easing in
	var guard := 0
	while Router.combat != null and guard < 60 * 12:
		guard += 1
		await tree.process_frame
	await _wait(4.0)
	await _wait(float(_arg("hold", "2")))
	print("fightfilm: done")
	tree.quit()
