extends Node

## A.S.H. IN A RUN, filmed with its sound, her lines coming at their own moments
## and her own limits deciding when (`Ash`):
##   godot --path . --resolution 1920x1080 --write-movie <dir>/film.avi --fixed-fps 30
##       -- sheet=AshFilm ash [seed=N]
## A new run: LOCAL as the ship comes in, and her launch line once it is at
## rest. A fight with a pirate cutter, the hull already worn (`hull=` share,
## 0.32): a turn of skills, END TURN and its volley -- the hull drops under a
## quarter -- and on the next turn the hull-failing line (a big moment: it does
## not wait out the quiet). Attacks until the cutter dies; its wreck on LOCAL.
## The wreck opened and its credits taken (a chit of HAUL_CREDITS and more is
## put in it), the window shut, and her big-haul line when the quiet after the
## last one is over. Every clock is the game's (`GameClock`, timers), so the
## movie writer's frames are true speed. Prints `mark <what> <seconds>`.

var _args: PackedStringArray
var _tree: SceneTree


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _wait(s: float) -> void:
	await _tree.create_timer(s).timeout


func _mark(what: String) -> void:
	print("mark %s %.2f" % [what, GameClock.now()])


func _speaking() -> bool:
	return Ash.portrait != null and Ash.portrait.speaking()


## Until she has said a line of `kind` and it has gone, or `limit` s.
func _until_said(kind: StringName, limit: float) -> void:
	var t0 := GameClock.now()
	var n := Ash.said_log.size()
	while GameClock.now() - t0 < limit:
		await _tree.process_frame
		if Ash.said_log.size() > n and StringName(Ash.said_log.back().kind) == kind:
			_mark("said_%s" % kind)
			break
	while _speaking() and GameClock.now() - t0 < limit + 10.0:
		await _tree.process_frame


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Ash.forced = true
	Ash.reload()
	Ash.set_on(true)
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.hand_size_override = 5
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.SYSTEM and not Router.no_fights_at(n):
			Run.at = n.index
			break
	Run.map[Run.at].visited = true
	_mark("local")
	Router.show_local()
	await _until_said(&"launch", 14.0)
	await _wait(1.5)

	# A FIGHT, the hull already worn
	Run.hp = int(round(Run.max_hp() * float(_arg("hull", "0.32"))))
	Sig.resources_changed.emit()
	Run.node_at().danger = maxi(Run.node_at().danger, 3)
	_mark("fight")
	Router.start_combat(DB.enemies[&"cutter"], [], false, false)
	var cb: Combat = Router.combat
	var e: Combat.EnemyState = cb.enemies[0]
	e.hp = mini(e.max_hp, 9)
	Sig.enemy_changed.emit()
	var sc := Router.current as SectorScreen
	await _wait(2.4)
	for k in 2:
		var pick := -1
		for i in cb.hand.size():
			var c: CardData = cb.hand[i]
			if cb.can_play(c) and c.damage <= 0:
				pick = i
				break
		if pick < 0:
			break
		cb.play(pick, 0)
		await _wait(1.1)
	await _wait(0.6)
	_mark("end_turn")
	sc._on_end_turn()
	await _wait(0.5)
	while sc._playing or sc._hold:
		await _tree.process_frame
	if Run.hp > int(Run.max_hp() * Ash.HURT_AT):
		# the volley missed or was light: the hull is where a second one would leave it
		Run.hp = int(Run.max_hp() * Ash.HURT_AT)
		Sig.resources_changed.emit()
	_mark("your_turn")
	await _until_said(&"hurt", 12.0)
	await _wait(0.8)
	for turn in 3:
		if e.hp <= 0 or cb.finished:
			break
		for k in 5:
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
			cb.play(pick, 0)
			await _wait(1.0)
		if e.hp > 0 and not cb.finished:
			Run.hp = maxi(Run.hp, 6)
			sc._on_end_turn()
			await _wait(0.5)
			while sc._playing or sc._hold:
				await _tree.process_frame
			await _wait(0.8)
	_mark("won")
	var guard := 0
	while Router.combat != null and guard < 60 * 12:
		guard += 1
		await _tree.process_frame
	await _wait(3.0)

	# THE WRECK, opened once the quiet is nearly over, its credits taken
	sc = Router.current as SectorScreen
	var n := Run.node_at()
	var wrecks := Run.wrecks_here(n)
	if sc == null or wrecks.is_empty():
		print("ashfilm: no wreck")
		_tree.quit()
		return
	var h: MapGen.Jetsam = wrecks.back()
	h.items.append(CreditChit.of(Ash.HAUL_CREDITS + 25))
	while Ash.now - Ash._last_end < Ash.COOLDOWN_S - 9.0:
		await _tree.process_frame
	_mark("open_wreck")
	sc._open_jetsam(h)
	await _wait(3.5)
	for i in h.items.size():
		if h.items[i] is CreditChit and not n.taken.has(h.option(i)):
			await Run.take_from_jetsam(n, h, i)
			if sc._transfer != null:
				sc._transfer.refresh()
			_mark("took_credits")
			await _wait(1.0)
	await _wait(1.5)
	sc._close_transfer()
	_mark("closed")
	await _until_said(&"haul", 20.0)
	await _wait(1.5)
	_mark("end")
	for row in Ash.said_log:
		print("ashfilm: said %s at %.1f: %s" % [row.kind, row.at, row.line])
	_tree.quit()
