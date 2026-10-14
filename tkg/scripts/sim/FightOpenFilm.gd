extends Node

## A FIGHT OPENING ON LOCAL, filmed whole with its sound, and every element's
## place on every frame of it:
##   godot --path . --resolution 1920x1080 --write-movie <dir>/f.png --fixed-fps 60
##       -- sheet=FightOpenFilm entry=<engage|event|ambush|pack|end> out=<dir> [animate]
## `engage`  the core: LOCAL with ENGAGE on the band, pressed (`_on_action`);
## `event`   an Escort event up on LOCAL, Take the contract, THEY ARE FIRING;
## `ambush`  a jump into a system where something is waiting: the departure,
##           the commit, and the fight that meets you there;
## `pack`    LOCAL at a system with its place drawn, a fight of three started
##           (`block=N`: shields up as they come; `kill`: the first killed once
##           the band has settled);
## `end`     a fight already under way, won, lowering into LOCAL (for comparison).
## `animate` turns the motion on headless (`Router.animate_in_harness`). Prints
## `mark <name> <frame>` (the movie writer's picture numbers are frames drawn)
## and writes `<out>/boxes.jsonl`, one `FightOpenProbe.sample` a frame with
## `f` (frame drawn) and `t` (game seconds from the trigger). Every clock the
## game's.

const Probe := preload("res://scripts/sim/FightOpenProbe.gd")

var _t := 0.0
var _out := ""
var _rec: FileAccess = null
var _t0 := -1.0
## Off: driven by `FightOpenTest`, which calls `play` and keeps the samples
## in `rows` rather than on disk.
var standalone := true
var rows: Array = []


func _mark(name: String) -> void:
	print("mark %s %d" % [name, Engine.get_frames_drawn()])


func _wait(s: float) -> void:
	var end := _t + s
	while _t < end:
		await get_tree().process_frame


func _process(delta: float) -> void:
	_t += delta


func _sample() -> void:
	if _rec == null and standalone:
		return
	var d := Probe.sample(Router.current as SectorScreen)
	d.f = Engine.get_frames_drawn()
	d.t = snappedf(_t - _t0, 0.0001) if _t0 >= 0.0 else -1.0
	d.cur = Router.current.get_class() if Router.current != null else ""
	d.inst = Router.current.get_instance_id() if Router.current != null else 0
	if _rec != null:
		_rec.store_line(JSON.stringify(d))
	else:
		rows.append(d)


func _ready() -> void:
	if standalone:
		_run.call_deferred()


func _arg(k: String, d: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with(k + "="):
			return (a as String).substr(k.length() + 1)
	return d


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	_out = _arg("out", "user://fightopen")
	DirAccess.make_dir_recursive_absolute(_out)
	if "animate" in OS.get_cmdline_user_args():
		Router.animate_in_harness = true
	_rec = FileAccess.open(_out.path_join("boxes.jsonl"), FileAccess.WRITE)
	await play(_arg("entry", "engage"), int(_arg("seed", "4242")))
	_rec.close()
	_rec = null
	_mark("end")
	print("fightopenfilm: done")
	tree.quit()


## One opening, from a fresh run: sampled every frame into `rows` (or the file).
func play(entry: String, seed_value: int = 4242) -> void:
	var tree := get_tree()
	rows = []
	_t0 = -1.0
	Rng.forced = seed_value
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.hand_size_override = 5
	if not tree.process_frame.is_connected(_sample):
		tree.process_frame.connect(_sample)
	match entry:
		"engage":
			await _engage()
		"event":
			await _event()
		"ambush":
			await _ambush()
		"pack":
			await _pack()
		"end":
			await _end_fight()
	tree.process_frame.disconnect(_sample)


## LOCAL at a system with its place drawn and nothing to read, and a fight of
## three started on it (the dev flag's pack, `Router.start_combat`).
func _pack() -> void:
	var n: MapGen.MapNode = null
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.SYSTEM and not Router.no_fights_at(m) and m.index != Run.at:
			n = m
			break
	OptionTable.ensure(n)
	n.ambush_rolled = true
	n.ambush_pending = false
	n.visited = true
	Run.at = n.index
	SectorScreen._approached_at = Run.at
	Router.show_local()
	await _wait(1.5)
	_mark("start")
	await _wait(1.0)
	_t0 = _t
	_mark("trigger")
	Router.start_combat(DB.enemies[&"cutter"], [DB.enemies[&"lancer"], DB.enemies[&"marauder"]], false, false)
	# `block=N`: every contact opens holding N block (its shield up as it comes)
	if _arg("block") != "" and Router.combat != null:
		for e in Router.combat.enemies:
			e.block = int(_arg("block"))
		Sig.enemy_changed.emit()
	await _settle()
	# `kill`: once the band has settled, the first contact is killed outright
	# (its breakup plays), and the film runs on a while
	if "kill" in OS.get_cmdline_user_args() and Router.combat != null:
		_mark("kill")
		Router.combat.damage_enemy(9999, 1, "film", Router.combat.enemies[0])
		await _wait(3.0)


## LOCAL at the core, ENGAGE pressed.
func _engage() -> void:
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.CORE:
			Run.at = n.index
	SectorScreen._approached_at = Run.at
	Router.show_local()
	await _wait(2.5)
	_mark("start")
	await _wait(1.0)
	_t0 = _t
	_mark("trigger")
	(Router.current as SectorScreen)._on_action()
	await _settle()


## An Escort event on LOCAL: take the contract, then THEY ARE FIRING.
func _event() -> void:
	var n: MapGen.MapNode = null
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.SYSTEM and not Router.no_fights_at(m) and m.index != Run.at:
			n = m
			break
	OptionTable.ensure(n)
	n.options.clear()
	n.options.append(&"escort")
	n.taken.clear()
	n.results.clear()
	n.cleared = false
	n.ambush_pending = false
	n.ambush_rolled = true
	n.visited = true
	Run.at = n.index
	SectorScreen._approached_at = Run.at
	LocalEventDrawer.request(n.index, 0)
	Router.show_local()
	await _wait(1.0)
	var sc := Router.current as SectorScreen
	var d: LocalEventDrawer = sc._events
	if d.text != null and not d.text.done:
		d.text.skip()
	await _wait(1.5)
	await d.choose(0)
	await _wait(0.6)
	if d.text != null and not d.text.done:
		d.text.skip()
	await _wait(1.0)
	_mark("start")
	await _wait(1.0)
	var go := d.find_child("TheyAreFiring", true, false) as Button
	_t0 = _t
	_mark("trigger")
	if go != null:
		go.pressed.emit()
	else:
		print("fightopenfilm: no THEY ARE FIRING")
	await _settle()


## A jump into a waiting ambush: depart, commit, the fight.
func _ambush() -> void:
	var here: MapGen.MapNode = Run.node_at()
	var to := -1
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.index != here.index and Run.can_jump_to(m) and not Router.no_fights_at(m) \
				and m.type == MapGen.NodeType.SYSTEM:
			to = m.index
			break
	if to < 0:
		print("fightopenfilm: nowhere to jump")
		return
	var t: MapGen.MapNode = Run.map[to]
	OptionTable.ensure(t)
	t.ambush_rolled = true
	t.ambush_pending = true
	SectorScreen._approached_at = Run.at
	Router.show_local()
	await _wait(2.5)
	_mark("start")
	await _wait(1.0)
	_t0 = _t
	_mark("trigger")
	Router.begin_jump(to)
	# the departure, then the fight
	var guard := 0.0
	while Router.combat == null and guard < 8.0:
		guard += 1.0 / 60.0
		await get_tree().process_frame
	_mark("fight")
	await _settle()


## A fight already up, won, lowering into LOCAL.
func _end_fight() -> void:
	var n: MapGen.MapNode = null
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.SYSTEM and not Router.no_fights_at(m):
			n = m
			break
	Run.at = n.index
	n.visited = true
	SectorScreen._approached_at = Run.at
	Router.show_local()
	await _wait(1.0)
	Router.start_combat(DB.enemies[&"cutter"], [], false, false)
	await _wait(3.0)
	var cb: Combat = Router.combat
	var e: Combat.EnemyState = cb.enemies[0]
	_mark("start")
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
				if _t0 < 0.0:
					_t0 = _t
					_mark("trigger")
				cb.play(i, 0)
				played = true
				break
		if not played and not cb.finished:
			cb.end_turn()
		await _wait(1.2)
	var guard := 0.0
	while Router.combat != null and guard < 12.0:
		guard += 1.0 / 60.0
		await get_tree().process_frame
	_mark("local")
	await _wait(2.0)


## Until the fight's band has stopped moving and its cards are in, then 2 s.
func _settle() -> void:
	var guard := 0.0
	var still := 0
	var last := Rect2()
	while guard < 10.0:
		guard += 1.0 / 60.0
		await get_tree().process_frame
		var sc := Router.current as SectorScreen
		if sc == null or not sc.fighting() or sc._hand_holder == null:
			continue
		var r := sc._hand_holder.get_global_rect()
		var dealt := sc._hand.get_child_count() > 0
		if r == last and dealt and sc._hand_holder.is_visible_in_tree():
			still += 1
		else:
			still = 0
		last = r
		if still >= 30:
			break
	_mark("settled")
	await _wait(maxf(0.0, float(_arg("hold", "2")) - 2.0))
	await _wait(2.0)
