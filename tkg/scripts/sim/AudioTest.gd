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
			Audio.CUSTODIAN_CUE: true, Audio.DEATH_CUE: true}
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

	# The Custodian alone gets Undertow; the Hellbender, a miniboss, keeps Last Stand.
	for row: Array in [[&"custodian", Audio.CUSTODIAN_CUE], [&"hellbender", Audio.BOSS_CUE]]:
		var asks: StringName = Router.fight_music(DB.enemies[row[0]])
		Audio.music_state(asks)
		await _settle()
		_ok("the %s's fight plays %s (asks %s, plays %s)" % [row[0], row[1], asks, Audio.cue()],
				Audio.cue() == row[1])
	_ok("and they are two cues, neither an ordinary fight's",
			Audio.CUSTODIAN_CUE != Audio.BOSS_CUE
			and not Audio.FIGHT_CUES.values().has(Audio.CUSTODIAN_CUE))

	# The hull pick is the Shipyard's hall: no score, the deck's bed as its room (Jon, Nov 11).
	Audio.music_state(&"lobby")
	await _settle()
	Audio.music_state(&"yard")
	await _settle()
	_ok("the yard stops the title cue (plays '%s')" % Audio.cue(), Audio.cue() == &"")
	# its rooms play their own beds (`HangarSound`, Jon's Nov 25 picks): no room tone under them
	var hull_pick := ChassisSelect.new()
	_ok("and has no room tone of its own", not Audio.ROOM_LEVELS.has(&"yard_bed") and Router._room_for(hull_pick) == &"")
	hull_pick.free()

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

	# Every grade rings its own sound as the sweep finds it, and a take only stows (Jon, Nov 18).
	# Why: docs/why/AudioTest.md#loot-ladder
	await _check_loot_ladder(tree)

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
## The ladder through the real loot screen: every grade, credits and a material in one wreck.
func _check_loot_ladder(tree: SceneTree) -> void:
	var names: Dictionary = {}
	var missing: Array = []
	var probes: Array[HoldItem] = [CreditChit.of(10)]
	var base: ModuleData = (DB.modules[&"plating"] as ModuleData)
	for r in range(ModuleData.Rarity.COMMON, ModuleData.Rarity.ARTIFACT + 1):
		var m := base.duplicate(true) as ModuleData
		DB.regrade(m, int(r))
		probes.append(m)
	for m in probes:
		var n := TransferView.tier_sound(m)
		names[n] = true
		if not ResourceLoader.exists(Audio.SFX_PATH % n):
			missing.append(n)
	_ok("seven grades and the credits are eight sounds (%s)" % [names.keys()], names.size() == 8)
	_ok("and every one is on disk (missing %s)" % [missing], missing.is_empty())

	var node: MapGen.MapNode = Run.node_at()
	node.jetsam.clear()
	node.taken.clear()
	Run.cargo.clear()
	var wreck := Run.new_wreck(node, DB.enemies[&"cutter"])
	wreck.items.assign(probes)
	wreck.items.append(MaterialData.of(MaterialTable.all()[0]))
	var view := TransferView.new()
	tree.root.add_child(view)
	var landed: Array = []
	var g: SalvageGrid = view._loose
	g.revealed.connect(func(m: HoldItem, _i: int) -> void: landed.append([m, GameClock.now(), _drawn(g, m)]))
	Audio.taping = true
	Audio.tape.clear()
	view.setup(wreck, node, func() -> void: pass, true)
	var reading := _reading(g, wreck.items)
	var t0 := Time.get_ticks_msec()
	while _ladder_rows().size() < wreck.items.size() and Time.get_ticks_msec() - t0 < 30000:
		await tree.process_frame
	await _settle(30)
	var want: Array[String] = []
	for m in reading:
		want.append(String(TransferView.tier_sound(m)))
	var rows := _ladder_rows()
	var heard: Array[String] = []
	for row in rows:
		heard.append(str(row[6]))
	var got: Array = landed.map(func(x: Array) -> HoldItem: return x[0])
	_ok("a wreck opening rings every thing it holds once, in reading order, each its own grade (%s)" % [heard],
		got == reading and heard == want)
	# One at a time, a second apart start to start, on the game clock the reveal runs on.
	var gaps: Array[float] = []
	for i in range(1, rows.size()):
		gaps.append(snappedf(float(rows[i][4]) - float(rows[i - 1][4]), 0.01))
	_ok("one at a time, about %.1f s apart (%s)" % [SalvageGrid.REVEAL_STEP, gaps],
		gaps.size() == wreck.items.size() - 1 and gaps.all(func(x: float) -> bool: return absf(x - SalvageGrid.REVEAL_STEP) <= 0.15))
	var on_cue := landed.size() == rows.size()
	for k in mini(landed.size(), rows.size()):
		on_cue = on_cue and bool(landed[k][2]) and absf(float(landed[k][1]) - float(rows[k][4])) <= 0.08
	_ok("each sound plays as its thing appears, drawn then", on_cue)

	# Opened again: everything at once, and silent.
	Audio.tape.clear()
	var again := TransferView.new()
	tree.root.add_child(again)
	again.setup(wreck, node, func() -> void: pass, true)
	await _settle(60)
	_ok("opened again it shows everything at once and rings nothing (%s)" % [_ladder_rows().size()],
		not again._loose.revealing() and _ladder_rows().is_empty())
	again.queue_free()

	# A skip: a click on the grid shows the rest with one sound, the best grade among them.
	var wreck2 := Run.new_wreck(node, DB.enemies[&"cutter"])
	for m in probes:
		wreck2.items.append(m.duplicate(true))
	var sk := TransferView.new()
	tree.root.add_child(sk)
	Audio.tape.clear()
	sk.setup(wreck2, node, func() -> void: pass, true)
	var g2: SalvageGrid = sk._loose
	var reading2 := _reading(g2, wreck2.items)
	t0 = Time.get_ticks_msec()
	while _ladder_rows().is_empty() and Time.get_ticks_msec() - t0 < 10000:
		await tree.process_frame
	Audio.tape.clear()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = (Vector2(g2._at[reading2[reading2.size() - 1]]) + Vector2(0.5, 0.5)) * float(SalvageGrid.CELL)
	g2._gui_input(click)
	t0 = Time.get_ticks_msec()
	while _ladder_rows().is_empty() and Time.get_ticks_msec() - t0 < 3000:
		await tree.process_frame
	var best := ""
	var best_g := -2
	for m: HoldItem in reading2.slice(1):
		var gr := -1 if m is CreditChit else int((m as ModuleData).rarity)
		if gr > best_g:
			best_g = gr
			best = String(TransferView.tier_sound(m))
	var after: Array = _ladder_rows().map(func(r: Array) -> String: return str(r[6]))
	_ok("a click on the grid shows the rest at once with one sound, the best grade left (%s, want %s)" % [after, best],
		not g2.revealing() and after == [best] and (g2.get_meta(&"rings", []) as Array).size() <= 1)
	sk.queue_free()

	# Taking is packing: the stow, whatever the grade.
	var top: HoldItem = probes[probes.size() - 1]
	Audio.tape.clear()
	await view._on_hold_drop({module = top, origin = &"bag"}, Vector2i.ZERO)
	await _settle(10)
	var took: Array[String] = []
	for row in Audio.tape:
		took.append(str((row as Array)[6]))
	_ok("taking the artifact plays the stow and none of the ladder (%s)" % [took],
		Run.cargo.has(top) and took.has("hold_stow") and _ladder_rows().is_empty())
	Audio.taping = false
	Audio.tape.clear()
	view.queue_free()


## Things in the order the reveal takes them: the top row left to right, then down.
func _reading(g: SalvageGrid, items: Array) -> Array:
	var out := items.duplicate()
	out.sort_custom(func(a: HoldItem, b: HoldItem) -> bool:
		var pa: Vector2i = g._at[a]
		var pb: Vector2i = g._at[b]
		return pa.y < pb.y or (pa.y == pb.y and pa.x < pb.x))
	return out


## Whether `m`'s own icon is showing in the grid.
func _drawn(g: SalvageGrid, m: HoldItem) -> bool:
	for c in g.get_children():
		if c is ItemIcon and (c as ItemIcon).held_item() == m:
			return (c as Control).visible
	return false


## The tape's rows that are the rarity ladder.
func _ladder_rows() -> Array[Array]:
	var out: Array[Array] = []
	for row in Audio.tape:
		if str((row as Array)[6]).begins_with("take_"):
			out.append(row)
	return out


func _settle(n: int = 200) -> void:
	for _i in n:
		await _tree.process_frame


func _finish() -> void:
	print("")
	verdict("audiotest")
	_tree.quit(code())
