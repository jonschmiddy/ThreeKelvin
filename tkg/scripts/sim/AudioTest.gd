extends Harness

## The music picks the right cue, loops without a gap, and leaves nothing behind.
##
##   godot --path . -- audiotest
##
## NOT HEADLESS, and for once not because of `frame_post_draw`. `Audio._ready`
## disables itself outright on a headless run or under `-- sim`, so the whole
## subject of this test does not exist there: it would pass by measuring
## nothing, which is the failure this project keeps finding in its own checks.
##
## WHAT IT GUARDED BEFORE, AND WHY THAT IS GONE. The previous edition built a
## cue out of six stems and loaded them on first use, and nothing released them
## -- a session that touched five places held all five decoded, at 17 MB each.
## That whole mechanism has been replaced by finished cues, one file
## apiece, played on two voices. There is no cache to leak, so the leak test is
## replaced rather than kept: what can go wrong now is picking the wrong cue,
## repeating one, stranding a voice, or a loop that does not come round.

var _tree: SceneTree


func run(tree: SceneTree) -> void:
	_tree = tree
	# DEAF TO THE DESK. This runs in a real window, and a window that takes a
	# key takes TAB -- which cycles ship, sector and chart, and every one of
	# those asks for run music. A keystroke meant for another program swapped
	# the cue under the test and failed it at random, one run in three while
	# anyone was typing. The test drives Audio directly; it wants no input.
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

	# ---- the table itself, before anything plays
	#
	# EVERY CUE THE GAME SHIPS IS REACHABLE. Six of the thirteen cues in the old
	# edition were unreachable for a year because the table that chose them
	# named seven places and there were thirteen pieces. Twenty-seven files is
	# a lot of work to leave unplayed, so this counts them rather than trusting.
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

	# ---- the tier ladder
	#
	# READ AS A TABLE, not by driving a run. The layer bands are the whole
	# decision and they are arithmetic, so they can be checked directly.
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

	# THE LADDER ONLY EVER CLIMBS. The whole argument for keying on layer rather
	# than danger is that a tier describes a journey, so a band that stepped
	# backwards would be the one thing this must not do.
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

	# ASKING FOR WHAT IS ALREADY ON DOES NOTHING. Router calls `music_state` on
	# every screen change, so this is the common case by a wide margin: if it
	# restarted the cue, walking to the station and back would reset the music.
	var held := Audio.cue()
	var voice := Audio._now
	Audio.play_cue(held)
	await _settle()
	_ok("asking again for the cue already playing changes nothing (%s)" % held,
			Audio.cue() == held and Audio._now == voice)

	# A TIER'S RUN CUES ALTERNATE. With two cues in most tiers, picking at
	# random without this would play the same piece twice in a row one time in
	# two, which is what makes a small set sound smaller than it is.
	var repeats := 0
	var prev := &""
	for _i in 12:
		var pick: StringName = Audio._pick(&"HARD", Audio.RUN_CUES[&"HARD"])
		if pick == prev:
			repeats += 1
		prev = pick
	_ok("a tier never plays the same run cue twice running (%d repeats in 12)"
			% repeats, repeats == 0)

	# ---- the loop
	#
	# THE ONE THING GODOT CANNOT DO FOR US. Its ogg import says where to jump
	# back TO and not where to loop FROM, and every cue carries six seconds of
	# reverb tail past its last bar -- so stream looping would play that tail
	# before every downbeat. `_relay` loops instead, and the tail rings over the
	# new head, which is what it was printed for.
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

	# ---- the one cue that must NOT loop
	#
	# Lights Out is fifty seconds of music and twenty of written silence. Relayed
	# like every other cue, a death would restart its own elegy every seventy
	# seconds for as long as the game-over screen sat there. So it is sought past
	# its loop point and the loop watcher is run by hand, and it has to leave it
	# alone.
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

	# ---- the cues that hang off a signal rather than off a screen
	#
	# WINNING IS QUIET NOW, and that is a decision rather than a gap. The tape is
	# what proves it: the wiring cannot be read for it, since `_connect_signals`
	# is never reached on a headless run.
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

	# ---- opening a wreck
	#
	# THE TOP OF THE LADDER RINGS AND THE REST DOES NOT. Read through the real
	# view rather than off the wiring: a wreck with a common and a legendary in
	# it, swept, and the tape says which of them was heard.
	Rng.reseed(4242, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var node: MapGen.MapNode = Run.node_at()
	node.jetsam.clear()
	node.taken.clear()
	Run.cargo.clear()
	var wreck := Run.new_wreck(node, DB.enemies[&"cutter"])
	for want in [ModuleData.Rarity.COMMON, ModuleData.Rarity.LEGENDARY]:
		for _i in 400:
			var m := LootGen.roll_module(5)
			if m != null and m.rarity == want:
				wreck.items.append(m)
				break
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
	_ok("and says nothing for the common beside it", not heard.has("take_common"))
	Audio.taping = false
	Audio.tape.clear()
	view.queue_free()

	# ---- stopping
	Audio.stop_music()
	await _settle()
	_ok("stopping clears the cue (%s)" % [Audio.cue()], Audio.cue() == &"")

	# NOTHING LEFT ON THE BUS. Two voices is the whole music system; a third
	# player on Music means something built one and lost it. The room tone has
	# its own player on this bus deliberately and is excluded by name.
	var players := 0
	for c in Audio.get_children():
		if c == Audio._room:
			continue
		if c is AudioStreamPlayer and (c as AudioStreamPlayer).bus == &"Music":
			players += 1
	_ok("exactly two music voices exist (%d on the bus)" % players,
			players == Audio._mv.size() and players == 2)

	# ---- the score sits back while there is a room at all
	#
	# DRIVEN, NOT WAITED FOR. `_rduck` eases over 1.6 seconds of real time, so
	# this walks the same `move_toward` the process loop does rather than sitting
	# through it.
	Audio.room(&"amb_station")
	var r := 1.0
	for _i in 400:
		r = move_toward(r, float(Audio.ROOM_DUCKS.get(Audio._room_now, 1.0)),
				0.016 / Audio.ROOM_DUCK_S)
	_ok("docked, the music steps back to %.0f%% (%.2f)"
			% [Audio.ROOM_DUCK * 100.0, r],
			is_equal_approx(r, Audio.ROOM_DUCK))
	# OPEN SPACE IS UNDER THE SCORE, NOT INSTEAD OF IT. Undocking into the
	# sector swaps rooms rather than clearing one, so this is the path a
	# player actually takes out of a station -- and the music has to return.
	Audio.room(&"amb_blue")
	for _i in 400:
		r = move_toward(r, float(Audio.ROOM_DUCKS.get(Audio._room_now, 1.0)),
				0.016 / Audio.ROOM_DUCK_S)
	_ok("and comes back up at a star (%.2f, room %s)" % [r, Audio._room_now],
			is_equal_approx(r, 1.0) and Audio._room_now == &"amb_blue")
	_ok("a star room has its own level, under the station's (%.1f vs %.1f dB)"
			% [Audio.ROOM_LEVELS[&"amb_blue"], Audio.ROOM_LEVELS[&"amb_station"]],
			ResourceLoader.exists(Audio.ROOM_PATH % "amb_blue")
			and float(Audio.ROOM_LEVELS[&"amb_blue"]) < float(Audio.ROOM_LEVELS[&"amb_station"]))
	Audio.room(&"")
	for _i in 400:
		r = move_toward(r, float(Audio.ROOM_DUCKS.get(Audio._room_now, 1.0)),
				0.016 / Audio.ROOM_DUCK_S)
	_ok("and with no room at all (%.2f)" % r, is_equal_approx(r, 1.0))

	# ---- the room ducks the score while somebody is talking
	Audio._load_speech(&"amb_station")
	_ok("the station bed says when it is talking (%d windows over %.0f s)"
			% [Audio._speech.size(), Audio._room_loop],
			Audio._speech.size() == 6 and Audio._room_loop > 1.0)
	var first: Array = Audio._speech[0] as Array
	var mid: float = (float(first[0]) + float(first[1])) * 0.5
	_ok("mid-announcement the music is asked to step aside (%.1f s)" % mid,
			Audio._talking_at(mid))
	_ok("and between them it is not (%.1f s)" % (float(first[1]) + 5.0),
			not Audio._talking_at(float(first[1]) + 5.0))
	# THE ONE THAT WOULD HAVE SHIPPED BROKEN. A looping stream's playhead keeps
	# counting past the end, so without the modulo the second pass through the
	# loop never ducks again -- and that is the pass a player actually hears.
	_ok("and it still ducks on the second time round (%.1f s)"
			% (Audio._room_loop + mid), Audio._talking_at(Audio._room_loop + mid))
	_finish()


## The cue files that actually shipped, read off the loop sidecar rather than
## the directory: a stray ogg in that folder is not a cue, and the sidecar is
## what the game reads at runtime anyway.
func _cues_on_disk() -> Dictionary:
	var out: Dictionary = {}
	Audio._loop_of(&"")                       ## forces the sidecar to load
	for c: StringName in Audio._loops:
		if c != &"":
			out[c] = true
	return out


## Advance far enough that a crossfade has finished, without waiting for real
## seconds. Bounded, because a loop that cannot end is worse than a failing
## check.
func _settle(n: int = 200) -> void:
	for _i in n:
		await _tree.process_frame


func _finish() -> void:
	print("")
	verdict("audiotest")
	_tree.quit(code())
