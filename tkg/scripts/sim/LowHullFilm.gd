extends Node

## THE HULL FAILING, FILMED (`LowHull`), with sound, at true speed:
##   godot --path . --resolution 1920x1080 --write-movie <dir>/film.avi --fixed-fps 30
##       -- sheet=LowHullFilm scene=<local|fight|cross|ash> [lowhull=subtle|medium|strong]
##          [hull=0.22] [secs=9] out=<dir>
##   local  LOCAL with the hull at `hull` of its max, the state already eased in
##   fight  a fight with a pirate cutter at `hull`; two cards played
##   cross  LOCAL at 45%, the hull dropping to 25% (on), then repaired to 60% (off)
##   ash    a fight at `hull`, and A.S.H. saying a hull-failing line in her voice,
##          glitched (`VoiceGlitch`), her portrait slipping in step
## Each runs a pre-roll first (the screen settling, the state easing in), then
## writes `marks.json` into `out`: the movie frame the film proper starts on,
## and the moments in it, in seconds from that start. Every clock is the game's.

var _args: PackedStringArray
var _tree: SceneTree
var _t0 := 0.0
var _f0 := 0
var _marks: Array = []


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _wait(s: float) -> void:
	var t := GameClock.now()
	while GameClock.now() - t < s:
		await _tree.process_frame


func _start() -> void:
	_t0 = GameClock.now()
	_f0 = Engine.get_process_frames()
	LowHull.glitch_log.clear()
	print("film start frame %d" % _f0)


func _mark(what: String) -> void:
	var at := GameClock.now() - _t0
	_marks.append({what = what, at = snappedf(at, 0.01)})
	print("mark %s %.2f" % [what, at])


func _share(s: float) -> void:
	Run.hp = maxi(1, int(floorf(Run.max_hp() * s)))
	SectorScreen.shown_hull = -1
	Sig.resources_changed.emit()


func _to_system() -> void:
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.SYSTEM and not Router.no_fights_at(n):
			Run.at = n.index
			break
	Run.map[Run.at].visited = true


func _fight() -> void:
	Run.node_at().danger = maxi(Run.node_at().danger, 3)
	Router.start_combat(DB.enemies[&"cutter"], [], false, false)
	var e: Combat.EnemyState = Router.combat.enemies[0]
	e.hp = e.max_hp
	Sig.enemy_changed.emit()


func _play_one() -> void:
	var cb := Router.combat
	if cb == null:
		return
	for i in cb.hand.size():
		var c: CardData = cb.hand[i]
		if cb.can_play(c) and c.damage <= 0:
			cb.play(i, 0)
			_mark("played " + c.name)
			return


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	var scene := _arg("scene", "local")
	var secs := float(_arg("secs", "9"))
	var hull := float(_arg("hull", "0.22"))
	print("film %s preset %s hull %.2f" % [scene, LowHull.Preset.keys()[LowHull.preset], hull])
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.hand_size_override = 5
	_to_system()
	match scene:
		"local":
			_share(hull)
			Router.show_local()
			await _wait(4.0)
			_start()
			await _wait(secs)
		"fight":
			_share(hull)
			Router.show_local()
			await _wait(1.0)
			_fight()
			await _wait(3.0)
			_start()
			await _wait(2.5)
			_play_one()
			await _wait(3.0)
			_play_one()
			await _wait(secs - 5.5)
		"cross":
			_share(0.45)
			Router.show_local()
			await _wait(4.0)
			_start()
			await _wait(1.5)
			_share(0.25)
			_mark("hull to 25%: on")
			await _wait(4.0)
			_share(0.6)
			_mark("repaired to 60%: off")
			await _wait(maxf(3.5, secs - 5.5))
		"ash":
			_share(hull)
			Router.show_local()
			await _wait(1.0)
			_fight()
			await _wait(3.0)
			_start()
			await _wait(0.6)
			Ash.forced = true
			Ash._on = true
			Ash._loaded = true
			Ash._last_end = -999.0
			var line := ""
			for l in AshLines.of(&"hurt"):
				if AshLines.voice_path(String(l)) != "" and String(l).length() > line.length():
					line = String(l)
			Ash._say(&"hurt", line, Ash._spot(line))
			_mark("she says: " + line)
			while Ash.portrait != null and Ash.portrait.voice_started_at < 0.0:
				await _tree.process_frame
			if Ash.portrait != null:
				_mark("her voice, %.2f s, heard glitched %s, its start %.2f ms on the main thread" % [
					Ash.portrait.voice_secs, Audio.voice_heard_glitched, Audio.voice_start_usec / 1000.0])
				for g: Dictionary in Audio.voice_glitches:
					_mark("voice glitch %s %.0f ms at +%.2f s" % [g.kind, float(g.len) * 1000.0, float(g.at)])
			var t := GameClock.now()
			while Ash.portrait != null and Ash.portrait.speaking() and GameClock.now() - t < 12.0:
				await _tree.process_frame
			if Ash.portrait != null:
				_mark("portrait slips in step: %d" % Ash.portrait.glitch_slips)
			await _wait(1.2)
	_mark("end")
	var kinds := ["", "slip", "split", "letter"]
	for g: Dictionary in LowHull.glitch_log:
		var words := "(gone)"
		if is_instance_valid(g.node):
			var c: Node = g.node
			if c is Label: words = (c as Label).text
			elif c is Button: words = (c as Button).text
			elif c is RichTextLabel: words = (c as RichTextLabel).get_parsed_text()
			else: words = c.get_class()
		_marks.append({what = "text glitch: %s on \"%s\"" % [kinds[int(g.kind)], words.left(30)],
			at = snappedf(float(g.at) - _t0, 0.01)})
	var out := _arg("out", "")
	if out != "":
		var f := FileAccess.open(out.path_join("marks.json"), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify({scene = scene, preset = LowHull.Preset.keys()[LowHull.preset].to_lower(),
				hull = hull, start_frame = _f0, glitches = LowHull.glitch_log.size(), marks = _marks}, "\t"))
	print("film done")
	_tree.quit()
