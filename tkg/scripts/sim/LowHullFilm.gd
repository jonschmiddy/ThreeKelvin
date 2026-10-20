extends Node

## THE HULL FAILING, FILMED (`LowHull`, `HullScramble`), with sound, at true speed:
##   godot --path . --resolution 1920x1080 --write-movie <dir>/film.avi --fixed-fps 30
##       -- sheet=LowHullFilm scene=<local|fight|tooltip|ramp> [lowhull=subtle|medium|strong]
##          [hull=0.22] [secs=8] [ash=1] out=<dir>
##   local    LOCAL with the hull at `hull` of its max, the state already eased in
##   fight    a fight with a pirate cutter at `hull`; two cards played
##   tooltip  LOCAL at `hull`, the HUD hull's tooltip up (built the way Godot
##            builds one: its TooltipPanel and TooltipLabel, under the cells)
##   ramp     LOCAL at 35%, the hull stepping to 30, 20, 10 and 5% every
##            `step` s (2.5), then repaired to 60%
##   `ash=1`: A.S.H. says the same line (`line_of`) a second in, glitched by the
##   hull's depth, her portrait slipping in step.
## Each runs a pre-roll first (the screen settling, the state easing in), then
## writes `marks.json` into `out`: the movie frame the film proper starts on,
## the moments in it in seconds from that start, and the scramble's measure
## (runs started a second, letters scrambled at once). Every clock is the game's.
##
##   godot --headless --path . -- sheet=LowHullFilm scene=voice out=<dir>
## writes `voice.wav`: her line (`line_of`) at 30, 20, 10 and 5% of the hull,
## back to back with VOICE_GAP_S of silence between, each through the same
## worker path she is heard through in play (`VoiceGlitch.bake_placed`), and
## `voice.json`, where each glitch is.

const VOICE_GAP_S := 0.5

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
	HullScramble.started_log.clear()
	print("film start frame %d" % _f0)


func _mark(what: String) -> void:
	var at := GameClock.now() - _t0
	_marks.append({what = what, at = snappedf(at, 0.01)})
	print("mark %s %.2f" % [what, at])


func _share(s: float) -> void:
	Run.hp = maxi(1, int(roundf(Run.max_hp() * s)))
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


## THE LINE every film and the voice reel say: her longest hull line with a take.
static func line_of() -> String:
	var line := ""
	for l in AshLines.of(&"hurt"):
		if AshLines.voice_path(String(l)) != "" and String(l).length() > line.length():
			line = String(l)
	return line


## A TOOLTIP, built the way Godot's viewport builds one for `target` (a plain
## `tooltip_text` in a TooltipPanel holding a TooltipLabel; or what the control's
## own `_make_custom_tooltip` gives), and shown under its middle. A harness's:
## a pushed mouse event does not move the game viewport's hover (`GameShell`),
## so the real one cannot be summoned headless or on the hidden desktop.
static func show_tip(target: Control) -> PopupPanel:
	var pp := PopupPanel.new()
	pp.theme_type_variation = &"TooltipPanel"
	pp.transient = true
	pp.unfocusable = true
	pp.mouse_passthrough = true
	var body: Control = null
	if target.has_method("_make_custom_tooltip"):
		body = target._make_custom_tooltip(target.tooltip_text) as Control
	if body == null:
		var l := Label.new()
		l.theme_type_variation = &"TooltipLabel"
		l.text = target.tooltip_text
		body = l
	pp.add_child(body)
	var host := LowHull.instance.get_parent()
	host.add_child(pp)
	var r := LowHull._screen_rect(target)
	pp.popup(Rect2i(Vector2i(r.get_center() + Vector2(10, 16)), Vector2i.ZERO))
	return pp


## Her line, said by a portrait of this film's own where she would stand
## (`Ash._spot`), so none of her own moments (her launch line) can come first.
var _ash: AshPortrait = null

func _say_line() -> void:
	var line := line_of()
	_ash = AshPortrait.new()
	_ash.top_level = true
	_ash.z_index = 50
	Ash._host().add_child(_ash)
	_ash.theme = Ash._theme()
	var spot: Dictionary = Ash._spot(line)
	_ash.mirrored = bool(spot.get("mirrored", false))
	if spot.has("rect"):
		_ash.position = (spot.rect as Rect2).position
	_ash.size = Vector2(AshPortrait.W, AshPortrait.H)
	_ash.say(line, &"hurt")
	_mark("she says (at %.0f%% hull): %s" % [100.0 * float(LowHull.shown().x) / float(LowHull.shown().y), line])
	while is_instance_valid(_ash) and _ash.voice_started_at < 0.0:
		await _tree.process_frame
	if is_instance_valid(_ash):
		_mark("her voice, %.2f s, heard glitched %s, its start %.2f ms on the main thread, %d glitches" % [
			_ash.voice_secs, Audio.voice_heard_glitched, Audio.voice_start_usec / 1000.0, Audio.voice_glitches.size()])
		for g: Dictionary in Audio.voice_glitches:
			_mark("voice glitch %s %.0f ms at +%.2f s" % [g.kind, float(g.len) * 1000.0, float(g.at)])


func _speaking() -> bool:
	return is_instance_valid(_ash) and _ash.phase != AshPortrait.Phase.GONE


func _measure(secs: float) -> Dictionary:
	var n0 := HullScramble.started_log.size()
	var sum := 0.0
	var frames := 0
	var t := GameClock.now()
	while GameClock.now() - t < secs:
		await _tree.process_frame
		sum += float(HullScramble.cells_now)
		frames += 1
	return {runs_a_second = snappedf(float(HullScramble.started_log.size() - n0) / secs, 0.01),
		letters_at_once = snappedf(sum / float(maxi(1, frames)), 0.01)}


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	var scene := _arg("scene", "local")
	if scene == "voice":
		_voice_reel()
		return
	var secs := float(_arg("secs", "8"))
	var hull := float(_arg("hull", "0.22"))
	var ash := _arg("ash", "0") == "1"
	print("film %s preset %s hull %.2f" % [scene, LowHull.Preset.keys()[LowHull.preset], hull])
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.hand_size_override = 5
	_to_system()
	var measure := {}
	match scene:
		"local":
			_share(hull)
			Router.show_local()
			await _wait(4.0)
			_start()
			if ash:
				await _wait(0.5)
				_say_line()
			measure = await _measure(secs - (0.5 if ash else 0.0))
			while ash and _speaking():
				await _tree.process_frame
		"fight":
			_share(hull)
			Router.show_local()
			await _wait(1.0)
			_fight()
			await _wait(3.0)
			_start()
			if ash:
				await _wait(0.6)
				_say_line()
			await _wait(2.0)
			_play_one()
			await _wait(3.0)
			_play_one()
			measure = await _measure(maxf(1.0, secs - 5.6))
		"tooltip":
			_share(hull)
			Router.show_local()
			await _wait(4.0)
			var tip: PopupPanel = null
			if Router.hud != null and Router.hud._hull != null:
				tip = show_tip(Router.hud._hull)
			await _wait(0.3)
			_start()
			_mark("the HUD hull's tooltip up")
			var hits := 0
			var t := GameClock.now()
			var n0 := HullScramble.started_log.size()
			while GameClock.now() - t < secs:
				await _tree.process_frame
			for row: Dictionary in HullScramble.started_log.slice(n0):
				var who = row.node
				if is_instance_valid(who) and tip != null and is_instance_valid(tip) and tip.is_ancestor_of(who):
					hits += 1
			_mark("scrambles in the tooltip: %d" % hits)
			measure = {runs_a_second = snappedf(float(HullScramble.started_log.size() - n0) / secs, 0.01)}
		"ramp":
			_share(0.35)
			Router.show_local()
			await _wait(4.0)
			_start()
			var step := float(_arg("step", "2.5"))
			await _wait(1.5)
			for lv in [0.30, 0.20, 0.10, 0.05]:
				_share(lv)
				_mark("hull to %.0f%%" % (lv * 100.0))
				var m := await _measure(step)
				measure["%.0f%%" % (lv * 100.0)] = m
			_share(0.6)
			_mark("repaired to 60%: eases off")
			await _wait(3.0)
	_mark("end")
	var out := _arg("out", "")
	if out != "":
		var f := FileAccess.open(out.path_join("marks.json"), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify({scene = scene, preset = LowHull.Preset.keys()[LowHull.preset].to_lower(),
				hull = hull, start_frame = _f0, scramble = measure, marks = _marks}, "\t"))
	print("film done")
	_tree.quit()


## Her line at each level, back to back, as heard in play (the worker's path).
func _voice_reel() -> void:
	var line := line_of()
	var path := AshLines.voice_path(line)
	var st := load(path) as AudioStream
	var sr := AudioServer.get_mix_rate()
	var gap := PackedByteArray()
	gap.resize(int(VOICE_GAP_S * sr) * 4)
	var all := PackedByteArray()
	var rows: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_arg("seed", "4242"))
	var at := 0.0
	for share in [0.30, 0.20, 0.10, 0.05]:
		var plan := LowHull.plan_for(st.get_length(), share, LowHull.look(), rng)
		var pb := st.instantiate_playback()
		var r := VoiceGlitch.bake_placed(pb, st.get_length(), sr, plan)
		var pcm: PackedByteArray = r.pcm
		rows.append({hull = share, starts_at = snappedf(at, 0.01), glitches = r.plan})
		all.append_array(pcm)
		at += float(pcm.size()) / 4.0 / sr
		all.append_array(gap)
		at += VOICE_GAP_S
		print("voice at %.0f%%: %d glitches" % [share * 100.0, (r.plan as Array).size()])
	var out := _arg("out", "user://")
	var wav := VoiceGlitch.from_pcm(all, sr) as AudioStreamWAV
	wav.save_to_wav(out.path_join("voice.wav"))
	var f := FileAccess.open(out.path_join("voice.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({line = line, take = path, gap_s = VOICE_GAP_S, preset = LowHull.Preset.keys()[LowHull.preset].to_lower(), levels = rows}, "\t"))
	print("voice reel done")
	_tree.quit()
