extends Node

## YOUR IDLE, SEEN AND HEARD, for Jon to hear the bed where it plays:
##   godot --path . --resolution 1920x1080 --write-movie <dir>/f.png --fixed-fps 60
##       -- sheet=IdleFilm [mode=arrive|fight] [hold=4] [seed=N]
## Godot's movie writer writes every frame and the game's own mix (`f.wav`) on
## the game clock, so it plays back at true speed.
##   arrive  a new run's first arrival on LOCAL: the name card, the drive, the
##           clean burn, the coughs sputtering down to the idle, then `hold`
##           seconds parked.
##   fight   a fight with a cutter: it flies in, one card played, then `hold`
##           seconds of the turn standing.
## Prints `mark <name> <seconds>` for the edges, with the bed's state.

var _args: PackedStringArray
var _t0 := 0.0


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


func _mark(what: String) -> void:
	var p: AudioStreamPlayer = Audio._idle_player
	print("mark %s %.2f  idle %s %.1f dB" % [what, GameClock.now() - _t0,
		"playing" if p != null and p.playing else "silent",
		p.volume_db if p != null else -80.0])


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	Rng.forced = int(_arg("seed", "4242"))
	Router.animate_in_harness = true
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_t0 = GameClock.now()
	var hold := float(_arg("hold", "4"))
	if _arg("mode", "arrive") == "fight":
		# away from the start, already arrived (as `FightFilm` does), so the
		# film is the fight and not the first system's arrival
		for n: MapGen.MapNode in Run.map:
			if n.type != MapGen.NodeType.STATION and n.type != MapGen.NodeType.START:
				Run.at = n.index
				break
		SectorScreen._approached_at = Run.at
		Router.start_combat(DB.enemies[&"cutter"], [], false, false)
		_mark("fight")
		await _wait(2.4)
		var cb: Combat = Router.combat
		for i in cb.hand.size():
			if cb.can_play(cb.hand[i]):
				cb.play(i, 0)
				_mark("card")
				break
		await _wait(hold)
	else:
		Router.show_local()
		var parked := false
		var heard := false
		for i in 60 * 20:
			await tree.process_frame
			var sc := Router.current as SectorScreen
			var art: ShipView = sc._view.ship_view() if sc != null and sc._view != null else null
			if art == null:
				continue
			if not heard and Audio.idle_want:
				heard = true
				_mark("idle_up")
			if heard and not parked and art._arrive_at < 0:
				parked = true
				_mark("parked")
				break
		await _wait(hold)
	_mark("end")
	tree.quit()
