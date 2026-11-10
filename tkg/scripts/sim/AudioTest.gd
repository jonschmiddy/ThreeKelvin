extends Harness

## Not headless: `Audio._ready` disables itself there, so it would pass measuring nothing.
## The old leak test went with the stem cache; checks now cover cue choice and loops.
## Why: docs/why/AudioTest.md#audio-test

var _tree: SceneTree


func run(tree: SceneTree) -> void:
	_tree = tree
	# Input is disabled: a stray TAB swapped the cue and failed the test one run in three.
	# Why: docs/why/AudioTest.md#audio-test
	tree.root.gui_disable_input = true
	var main := tree.current_scene
	if main != null:
		main.set_process_input(false)
		main.set_process_unhandled_input(false)
		main.set_process_unhandled_key_input(false)
	await tree.process_frame

	if not _ok("audio is enabled, so there is something here to measure",
			Audio._enabled):
		return _finish()

	# Counts every shipped cue as reachable: six of thirteen were unreachable for a year.
	# Why: docs/why/AudioTest.md#cue-table
	var named: Dictionary = {Audio.TITLE_CUE: true, Audio.BOSS_CUE: true,
			Audio.DEATH_CUE: true}
	for tier: StringName in Audio.RUN_CUES:
		for c: StringName in Audio.RUN_CUES[tier]:
			named[c] = true
	for tier: StringName in Audio.FIGHT_CUES:
		named[Audio.FIGHT_CUES[tier]] = true
	var on_disk := _cues_on_disk()
	var unplayed: Array = []
	for c: StringName in on_disk:
		if not named.has(c):
			unplayed.append(c)
	_ok("every cue on disk is reachable in play (%d cues, orphans %s)"
			% [on_disk.size(), unplayed], unplayed.is_empty())

	var missing: Array = []
	for c: StringName in named:
		if not on_disk.has(c):
			missing.append(c)
	_ok("and every cue the table names exists (%d named, missing %s)"
			% [named.size(), missing], missing.is_empty())

	# Three fight cues by danger (Jon, Nov 10). Why: docs/why/Audio.md#music-cues
	var f: Array = Audio.TIERS.map(func(t: StringName) -> StringName: return Audio.FIGHT_CUES[t])
	_ok("fights by danger: EASY = ROUGH, HARD alone, BRUTAL = LETHAL, three cues (%s)" % [f],
			f[0] == f[1] and f[3] == f[4] and f[1] != f[2] and f[2] != f[3] and f[0] != f[4])

	# Read as a table, not by driving a run: the layer bands are arithmetic.
	_ok("five tiers over %d layers, %d apiece"
			% [MapGen.LAYERS, Audio.TIER_SPAN],
			Audio.TIERS.size() * Audio.TIER_SPAN == MapGen.LAYERS)

	var ladder: Array[StringName] = []
	for layer in MapGen.LAYERS:
		ladder.append(Audio.TIERS[clampi(layer / Audio.TIER_SPAN, 0,
				Audio.TIERS.size() - 1)])
	_ok("layer 0 opens on EASY and the last layer is LETHAL (%s .. %s)"
			% [ladder[0], ladder[ladder.size() - 1]],
			ladder[0] == &"EASY" and ladder[ladder.size() - 1] == &"LETHAL")

	# The ladder only climbs: a tier describes a journey, which is why it keys on layer.
	var climbs := true
	for i in range(1, ladder.size()):
		if Audio.TIERS.find(ladder[i]) < Audio.TIERS.find(ladder[i - 1]):
			climbs = false
	_ok("and it never steps back down (%s)"
			% [" ".join(ladder.map(func(t: StringName) -> String:
					return str(t).substr(0, 1)))], climbs)

	# ---- playing, swapping, and not repeating
	Audio.play_cue(Audio.TITLE_CUE)
	await _settle()
	_ok("the title plays (%s, voice %d)" % [Audio.cue(), Audio._now],
			Audio.cue() == Audio.TITLE_CUE and Audio._now >= 0)

	var first_voice := Audio._now
	Audio.play_cue(Audio.FIGHT_CUES[&"LETHAL"])
	await _settle()
	_ok("a different cue takes the other voice (%s, voice %d)"
			% [Audio.cue(), Audio._now],
			Audio.cue() == Audio.FIGHT_CUES[&"LETHAL"]
			and Audio._now != first_voice)

	# Asking for what is playing does nothing, so walking to the station and back keeps the music.
	var held := Audio.cue()
	var voice := Audio._now
	Audio.play_cue(held)
	await _settle()
	_ok("asking again for the cue already playing changes nothing (%s)" % held,
			Audio.cue() == held and Audio._now == voice)

	# A tier's run cues alternate; random picks would repeat one time in two.
	var repeats := 0
	var prev := &""
	for _i in 12:
		var pick: StringName = Audio._pick(&"HARD", Audio.RUN_CUES[&"HARD"])
		if pick == prev:
			repeats += 1
		prev = pick
	_ok("a tier never plays the same run cue twice running (%d repeats in 12)"
			% repeats, repeats == 0)

	# Godot's ogg loop gives no loop-from point, so `_relay` loops and the tail rings over.
	# Why: docs/why/AudioTest.md#loop
	var loops_ok := true
	var no_loop: Array = []
	for c: StringName in named:
		if Audio._loop_of(c) <= 0.0:
			loops_ok = false
			no_loop.append(c)
	_ok("every cue knows its loop point (%s)"
			% ("all %d" % named.size() if loops_ok else str(no_loop)), loops_ok)

	var streamed := true
	for i in Audio._mv.size():
		var st: AudioStream = (Audio._mv[i] as AudioStreamPlayer).stream
		if st is AudioStreamOggVorbis and (st as AudioStreamOggVorbis).loop:
			streamed = false
	_ok("and no cue is left to the stream's own looping", streamed)

	# The relay itself, driven rather than waited for: a cue is two minutes long
	# and this test is not going to sit through one.
	var before_voice := Audio._now
	var carried: AudioStream = (Audio._mv[Audio._now] as AudioStreamPlayer).stream
	Audio._relay()
	await tree.process_frame
	_ok("the loop hands the cue to the other voice (%d -> %d)"
			% [before_voice, Audio._now], Audio._now != before_voice)
	_ok("and the new voice carries the same cue",
			(Audio._mv[Audio._now] as AudioStreamPlayer).stream == carried
			and (Audio._mv[Audio._now] as AudioStreamPlayer).playing)

	# A cue change inside the relay's tail reuses the old voice; the tail's stop must not reach it.
	Audio.play_cue(Audio.TITLE_CUE)
	await _settle()
	await tree.create_timer(Audio.TAIL).timeout
	_ok("a cue changed inside a relay's tail is still playing after the tail (%s)" % Audio.cue(),
			Audio.cue() == Audio.TITLE_CUE and (Audio._mv[Audio._now] as AudioStreamPlayer).playing)

	# Lights Out must not loop: relayed, a death would restart its elegy every seventy seconds.
	# Why: docs/why/AudioTest.md#loop
	Audio.music_state(&"gameover")
	await _settle()
	_ok("a death plays Lights Out (%s)" % Audio.cue(),
			Audio.cue() == Audio.DEATH_CUE)
	var dv := Audio._now
	(Audio._mv[dv] as AudioStreamPlayer).seek(Audio._loop_of(Audio.DEATH_CUE) + 0.5)
	Audio._process(0.016)
	await tree.process_frame
	_ok("and it runs out rather than looping (voice %d stays %d)" % [dv, Audio._now],
			Audio._now == dv)

	# Winning is quiet by decision; the tape proves it, as `_connect_signals` is skipped headless.
	# A run first: Router logs the hull on a fight's end, and with no hull that was a SCRIPT ERROR.
	seed_run(4242)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Audio.taping = true
	Audio.tape.clear()
	Sig.combat_ended.emit(&"victory", "")
	await tree.process_frame
	var played: Array = []
	for row in Audio.tape:
		played.append(str((row as Array)[0]))
	_ok("winning a fight plays no sting (%s)" % [played], played.is_empty())
	Audio.taping = false
	Audio.tape.clear()

	# The top of the rarity ladder rings and the rest does not, read through the real view.
	var node: MapGen.MapNode = Run.node_at()
	node.jetsam.clear()
	node.taken.clear()
	Run.cargo.clear()
	var wreck := Run.new_wreck(node, DB.enemies[&"cutter"])
	for want in [ModuleData.Rarity.COMMON, ModuleData.Rarity.LEGENDARY]:
		for _i in 400:
			# Commons drop shallower than tier 3 only (`LootGen.NO_COMMON_TIER`).
			var m := LootGen.roll_module(1 if want == ModuleData.Rarity.COMMON else 5)
			if m != null and m.rarity == want:
				wreck.items.append(m)
				break
	var placed_common := wreck.items.any(func(m: ModuleData) -> bool: return m.rarity == ModuleData.Rarity.COMMON)
	var view := TransferView.new()
	tree.root.add_child(view)
	Audio.taping = true
	Audio.tape.clear()
	view.setup(wreck, node, func() -> void: pass, true)
	await _settle(400)
	var heard: Array = []
	for row in Audio.tape:
		heard.append(str((row as Array)[0]))
	_ok("a wreck opening rings a legendary (%s)" % [heard], heard.has("take_legendary"))
	_ok("and says nothing for the common beside it", placed_common and not heard.has("take_common"))
	Audio.taping = false
	Audio.tape.clear()
	view.queue_free()

	# ---- stopping
	Audio.stop_music()
	await _settle()
	_ok("stopping clears the cue (%s)" % [Audio.cue()], Audio.cue() == &"")

	# Two voices are the whole music system; a third player on Music means a lost build.
	var players := 0
	for c in Audio.get_children():
		if c is AudioStreamPlayer and (c as AudioStreamPlayer).bus == &"Music":
			players += 1
	_ok("exactly two music voices exist (%d on the bus)" % players,
			players == Audio._mv.size() and players == 2)

	# The room is not on the music fader (Jon): turning the score down took the reactor with it.
	Audio.room(&"amb_station")
	_ok("room tone plays on its own bus (%s)" % Audio._room.bus,
			Audio._room != null and Audio._room.bus == &"Ambient"
			and AudioServer.get_bus_index(&"Ambient") >= 0)

	# Driven, not waited for: `_rduck` eases over 1.6 s, so walk the same `move_toward`.
	Audio.room(&"amb_station")
	var r := 1.0
	for _i in 400:
		r = move_toward(r, float(Audio.ROOM_DUCKS.get(Audio._room_now, 1.0)),
				0.016 / Audio.ROOM_DUCK_S)
	_ok("docked, the music steps back to %.0f%% (%.2f)"
			% [Audio.ROOM_DUCK * 100.0, r],
			is_equal_approx(r, Audio.ROOM_DUCK))
	# Open space sits under the score, not instead of it; undocking swaps rooms, music returns.
	Audio.room(&"amb_blue")
	for _i in 400:
		r = move_toward(r, float(Audio.ROOM_DUCKS.get(Audio._room_now, 1.0)),
				0.016 / Audio.ROOM_DUCK_S)
	_ok("and comes back up at a star (%.2f, room %s)" % [r, Audio._room_now],
			is_equal_approx(r, 1.0) and Audio._room_now == &"amb_blue")
	# Checked in LUFS, not RMS: RMS misjudged the blue room by 6.2 dB, which Jon heard.
	# Why: docs/why/AudioTest.md#room-levels
	var off: Array = []
	for nm: StringName in Audio.ROOM_TARGET:
		var got: float = float((Audio.ROOM_FILE_DB[nm] as Array)[1]) 				+ float(Audio.ROOM_LEVELS[nm])
		if absf(got - float(Audio.ROOM_TARGET[nm])) > 0.15:
			off.append("%s %.1f wanted %.1f" % [nm, got, Audio.ROOM_TARGET[nm]])
	_ok("every room plays where it is meant to%s"
			% ("" if off.is_empty() else " -- " + ", ".join(off)), off.is_empty())

	# AND THE SHAPE HOLDS: an empty system is your own reactor, a star is
	# something outside making a noise, and the station is its own case.
	var bed: float = float(Audio.ROOM_TARGET[&"amb_space"])
	var quiet_star: float = minf(minf(float(Audio.ROOM_TARGET[&"amb_blue"]),
			float(Audio.ROOM_TARGET[&"amb_red"])), float(Audio.ROOM_TARGET[&"amb_pulsar"]))
	_ok("open space sits under every star (%.1f vs %.1f LUFS)" % [bed, quiet_star],
			bed < quiet_star and float(Audio.ROOM_TARGET[&"amb_station"]) < bed)
	Audio.room(&"")
	for _i in 400:
		r = move_toward(r, float(Audio.ROOM_DUCKS.get(Audio._room_now, 1.0)),
				0.016 / Audio.ROOM_DUCK_S)
	_ok("and with no room at all (%.2f)" % r, is_equal_approx(r, 1.0))

	# The game deals the lines in a new order (Jon), so the checks moved off a timetable.
	# Why: docs/why/AudioTest.md#station-announcements
	Audio._load_pa(&"amb_station")
	var lines: int = Audio._pa_lines.size()
	var absent: Array = []
	for row: Variant in Audio._pa_lines:
		var nm := String((row as Dictionary).get("name", ""))
		if not ResourceLoader.exists("res://assets/audio/ambience/%s.ogg" % nm):
			absent.append(nm)
	_ok("the station has %d lines and every one is on disk %s" % [lines, absent],
			lines >= 8 and absent.is_empty())

	# A bag, not a roll: random draws of sixteen lines would repeat about one dock in eight.
	var seen: Dictionary = {}
	var repeat := -1
	for i in lines:
		Audio._deal_pa()
		var nm := Audio._pa.stream.resource_path if Audio._pa != null else ""
		if seen.has(nm) and repeat < 0:
			repeat = i
		seen[nm] = true
	_ok("it says all %d before it says any of them twice (%d distinct, first repeat %s)"
			% [lines, seen.size(), "none" if repeat < 0 else str(repeat)],
			seen.size() == lines and repeat < 0)

	# AND THE MUSIC STEPS ASIDE FOR IT, which is the whole reason the game needs
	# to know a line is playing at all.
	_ok("while a line is playing the score is asked to step aside",
			Audio._room_talking())
	Audio._pa.stop()
	_ok("and when it stops, it is not", not Audio._room_talking())

	_finish()


## Read off the loop sidecar, which the game reads; a stray ogg is not a cue.
func _cues_on_disk() -> Dictionary:
	var out: Dictionary = {}
	Audio._loop_of(&"")                       ## forces the sidecar to load
	for c: StringName in Audio._loops:
		if c != &"":
			out[c] = true
	return out


## Advance until a crossfade ends, bounded: a loop that cannot end is worse than a failed check.
func _settle(n: int = 200) -> void:
	for _i in n:
		await _tree.process_frame


func _finish() -> void:
	print("")
	verdict("audiotest")
	_tree.quit(code())
