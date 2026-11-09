extends Node
## Second edition: no tempo, one low F pedal shared by every cue, so crossfades still work.
## The first edition was called hollow; the fault was the form, not the details.
## Why: docs/why/Audio.md#music-design

const SFX_PATH := "res://assets/audio/sfx/%s.wav"
## PCM where it loops: Vorbis edges click once a lap (ogg x53 against wav x0.4).
## Why: docs/why/Audio.md#room-tone-loops
const ROOM_WAV := "res://assets/audio/ambience/%s.wav"
const ROOM_PATH := "res://assets/audio/ambience/%s.ogg"

const OFF_DB := -60.0      ## silent, but still a running player
const SFX_VOICES := 14
## Fraction of heat capacity that counts as "running hot".
const HEAT_WARN_AT := 0.8

var master_volume: float = 0.9
var music_volume: float = 0.7
var sfx_volume: float = 0.9
## Own fader, starting at Music's level so the tuned room levels are not quietly retuned.
## Why: docs/why/Audio.md#ambient-fader
var ambient_volume: float = 0.7

## THE TWO MUSIC VOICES, and everything the cue system now needs. One carries
## what is playing, the other is free for the next cue or the next lap.
var _mv: Array[AudioStreamPlayer] = []
var _mfade: Array[Tween] = []       ## one per voice, killable, same rule as _fade
var _now: int = -1                  ## which voice has the cue, or -1 for none
var _cue: StringName = &""
var _last_pick: Dictionary = {}     ## tier -> last index, so a cue never repeats
var _loops: Dictionary = {}         ## cue -> seconds of musical loop
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
## One per voice, killable: a lingering fade tween would take the next sound with it.
var _fade: Array[Tween] = []
var _cache: Dictionary = {}
var _variants: Dictionary = {}  ## name -> [name, name_2, ...] round robins
## For harnesses: while `taping`, every effect that really played is appended to a tape.
var taping: bool = false
var tape: Array = []
## Every `hush` asked for while taping: [the names, the process frame].
var hushed: Array = []
var _last: Dictionary = {}          ## sfx name -> msec, for rate limiting
var _enabled: bool = true
var _last_credits: int = -1
var _last_cargo: int = -1
var _hot: bool = false

## ---------------- room tone ----------------
## One player, one room at a time: a second room under the first is a bug.
var _room: AudioStreamPlayer = null
var _room_now: StringName = &""
var _room_fade: Tween = null
## Measured, not chosen. Re-derive after any change to MIXDB in `station.py`.
## Why: docs/why/Audio.md#room-levels
const ROOM_DB := -14.0
## Set by ear, levelled in LUFS not RMS; each number is target minus the file's own reading.
## Why: docs/why/Audio.md#room-levels
const ROOM_LEVELS: Dictionary = {&"amb_space": -14.3, &"amb_blue": -14.5,
		&"amb_red": -9.2, &"amb_pulsar": -8.5, &"amb_station": -15.4}
## As the build scripts measured them; the test re-does the arithmetic.
const ROOM_FILE_DB: Dictionary = {
		&"amb_space": [-15.7, -12.0], &"amb_blue": [-15.6, -10.2],
		&"amb_red": [-12.7, -13.4], &"amb_pulsar": [-13.5, -14.3],
		&"amb_station": [-30.3, -26.5]}
const ROOM_TARGET: Dictionary = {&"amb_space": -26.3, &"amb_blue": -24.7,
		&"amb_red": -22.6, &"amb_pulsar": -22.8, &"amb_station": -41.9}
const ROOM_FADE := 1.6     ## seconds, because a room does not arrive on a beat

## The score steps aside while a PA line is read; the playhead says when, with no analysis.
## Why: docs/why/Audio.md#station-duck
const DUCK_DB := -9.0      ## how far the music drops under an announcement
const DUCK_IN := 0.35      ## seconds down: quick, or the first words are lost
const DUCK_OUT := 1.20     ## and slow back up, so it is not a pumping effect
## THE STATION'S OWN VOICE. The lines it can say, the ones it has not said yet,
## and how long until the next.
const PA_GAP := Vector2(34.0, 68.0)    ## seconds of quiet between lines
const PA_FIRST := Vector2(6.0, 16.0)   ## and before the first one, after docking
var _pa: AudioStreamPlayer = null
var _pa_lines: Array = []
var _pa_bag: Array[int] = []
var _pa_next: float = 0.0
var _duck: float = 1.0     ## 1 is unducked; multiplies every music stem

## A docked station is its own room: the score goes silent and resumes mid-phrase on leaving.
## Why: docs/why/Audio.md#station-duck
const ROOM_DUCK := 0.0     ## silent, while docked
## Only the station pushes the score aside; open space sits under the music.
const ROOM_DUCKS: Dictionary = {&"amb_station": ROOM_DUCK}
const ROOM_DUCK_S := 1.6   ## and it arrives with the room, not before it
var _rduck: float = 1.0

# ---------------- the bed ----------------
# Room tone is not a cue: it needs its own player and a fade in seconds, not beats.
# Why: docs/why/Audio.md#room-tone-history

## Room tone is back as `amb_station`, outside the cue system, assembled and not synthesised.
## Why: docs/why/Audio.md#room-tone-history

func _ready() -> void:
	# the idle bed decides on a headless run too, so a test can read it
	_idle_clock = IdleClock.new()
	_idle_clock.audio = self
	add_child(_idle_clock)
	# Harness switches: `fx=row:choice,...` picks takes, `sfxtape=<json>` tapes every sound.
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("fx="):
			_fx_args(a.substr(3))
		elif a.begins_with("sfxtape="):
			_tape_to = a.substr(8)
			taping = true
	# The balance sim has no audio device; loading 36 MB of streams would be pure cost.
	if "sim" in OS.get_cmdline_user_args():
		_enabled = false
		return
	# Headless is silent but wired, so a taping harness can read what would have played.
	if DisplayServer.get_name() == "headless":
		_enabled = false
		_connect_signals()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS      ## music keeps playing while paused
	load_settings()
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx.append(p)
		_fade.append(null)
	_connect_signals()


## Systems emit on Sig and never reach across scenes, so this is where the
## whole game's sound wiring lives — one place to read, one place to retune.
func _connect_signals() -> void:
	Sig.card_played.connect(_on_card_played)
	# Play on the frame the shot arrives: `damage_dealt` fires 8 to 17 frames early.
	# Why: docs/why/Audio.md#hit-sound-timing
	Sig.hit_landed.connect(_on_hit_landed)
	# Release of a charged card is a heavy shot; Jon asked for separate charge and release sounds.
	# Why: docs/why/Audio.md#charge-sounds
	Sig.charge_fired.connect(func(_n: String) -> void: play(&"shot_heavy", 0.05))
	# No sting when a fight starts: the Hard Burn cue already says it.
	# Why: docs/why/Audio.md#signal-sounds
	Sig.combat_ended.connect(_on_combat_ended)
	# No sound on `Sig.jumped`: Jon cut `jump`, and the convoy plays `hyperjump` itself.
	# Why: docs/why/Audio.md#signal-sounds
	Sig.contracts_changed.connect(func() -> void:
		play(&"contract_stamp", 0.04, 250))
	# `_swap()` is the one chokepoint; the 60 ms limit soaks double swaps without eating clicks.
	# Why: docs/why/Audio.md#signal-sounds
	Sig.screen_changed.connect(func() -> void:
		play(&"ui_tab", 0.04, 60))
	# Desk actions play their own sounds at the UI call sites, not on `ship_changed`.
	Sig.run_ended.connect(_on_run_ended)
	# Draw on turn start, not `hand_changed`, which also fires when a card leaves the hand.
	Sig.player_combat_state_changed.connect(_on_combat_state)
	Sig.resources_changed.connect(_poll_resources)
	Sig.screen_changed.connect(_poll_resources)
	Sig.run_started.connect(func() -> void:
		_last_credits = -1
		_last_cargo = -1
		_hot = false)

# ---------------- music ----------------
# One file per cue, not a stack of stems: intensity is a different piece, not more of one.
# Why: docs/why/Audio.md#music-cues

## Four run cues a tier, so not-the-same-twice becomes a real shuffle.
## Why: docs/why/Audio.md#music-cues
const RUN_CUES := {
	&"EASY":   [&"fl", &"coldstart", &"longway", &"driftplane"],
	&"ROUGH":  [&"ghostfreight", &"salvage", &"cutsignal", &"qo"],
	&"HARD":   [&"redline", &"deadweight", &"coldiron", &"thinice"],
	&"BRUTAL": [&"nothingleft", &"wrongship", &"countdown", &"attrition"],
	&"LETHAL": [&"eventhorizon", &"noair", &"sealed", &"aftermath"],
}
const FIGHT_CUES := {
	&"EASY": &"closequarters", &"ROUGH": &"slipstream", &"HARD": &"hairline",
	&"BRUTAL": &"overpressure", &"LETHAL": &"laststand",
}
const TITLE_CUE := &"title"
## The boss gets the boss cue whatever the depth. `tiers.md` gives Last Stand to
## LETHAL's fight AND to the boss, and a boss met early is still a boss.
const BOSS_CUE := &"laststand"
## Lights Out plays once and runs out: looped, a death would restart its elegy every 70 s.
const DEATH_CUE := &"lightsout"
const ONE_SHOT: Array[StringName] = [DEATH_CUE]

## Tier follows layer (15 layers, 5 tiers), as a journey only goes one way.
const TIERS: Array[StringName] = [&"EASY", &"ROUGH", &"HARD", &"BRUTAL", &"LETHAL"]
const TIER_SPAN := 3

## A bad system plays one tier up, keeping the old `DREAD_DANGER` ruling.
const DREAD_DANGER := 8

## Musical loop seconds per cue, not file length: the reverb tail is why `_relay` works.
const LOOPS_PATH := "res://assets/audio/music/loops.json"
const MUSIC_PATH := "res://assets/audio/music/%s.ogg"
const TAIL := 6.0          ## seconds of tail after the loop point, by construction
const SWAP := 2.5          ## crossfade between two different cues

## Cues were normalised to about -1 dBFS and played at full gain; Jon found them 5x too loud.
## Why: docs/why/Audio.md#music-level
const MUSIC_DB := -14.0
## Kept here, not on the bus, so `music_volume` stays the player's and keeps its full travel.
## Why: docs/why/Audio.md#music-level

## Kept even with audio off, so a headless harness can read which cue a screen wired.
var music_asked: StringName = &""

func music_state(state: StringName) -> void:
	music_asked = state
	if not _enabled:
		return
	# A panel asks for nothing: Jon does not want the music to change when he changes panels.
	# Why: docs/why/Audio.md#panels-and-music
	match state:
		&"menu", &"lobby":
			play_cue(TITLE_CUE)
		&"gameover":
			# Lights Out plays once, then silence; the silence is written into the file's end.
			play_cue(DEATH_CUE)
		&"boss":
			play_cue(BOSS_CUE)
		&"combat":
			play_cue(FIGHT_CUES[_tier()])
		_:
			_run_music()

## Picked once and left alone, so moving between places never touches the music.
func _run_music() -> void:
	var tier := _tier()
	var cues: Array = RUN_CUES[tier]
	if _cue in cues:
		return                                  ## already somewhere in this tier
	play_cue(_pick(tier, cues))

## Not the same cue twice running: a repeat makes a small set feel smaller.
func _pick(tier: StringName, cues: Array) -> StringName:
	if cues.size() == 1:
		return cues[0]
	var last: int = int(_last_pick.get(tier, -1))
	var i := last
	while i == last:
		i = randi() % cues.size()
	_last_pick[tier] = i
	return cues[i]

## Depth, in five steps, with a dangerous system worth one step on its own.
func _tier() -> StringName:
	var i := clampi(_layer() / TIER_SPAN, 0, TIERS.size() - 1)
	if _danger() >= DREAD_DANGER:
		i = mini(i + 1, TIERS.size() - 1)
	return TIERS[i]

func _layer() -> int:
	if Run.map.is_empty():
		return 0
	var n: MapGen.MapNode = Run.node_at()
	return 0 if n == null else n.layer

func _danger() -> int:
	# Screens change before a run exists (menu, first boot), and node_at() is
	# null between a jump being spent and the next node being resolved.
	if Run.map.is_empty():
		return 0
	var n: MapGen.MapNode = Run.node_at()
	return 0 if n == null else n.danger

## Put a cue on, crossfading from whatever is there. Asking for the cue that is
## already playing does nothing, so callers never have to check.
func play_cue(cue: StringName) -> void:
	if not _enabled or cue == _cue:
		return
	var stream: AudioStream = load(MUSIC_PATH % cue)
	if stream == null:
		push_warning("Audio: missing cue %s" % cue)
		return
	# Not looped by the stream: it would play the six-second tail before every downbeat.
	# `_relay` loops instead and uses the tail.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	_cue = cue
	_swap_to(stream, SWAP)

## Faded, never cut, through one killed tween so fast tabbing leaves no two fades fighting.
## Why: docs/why/Audio.md#room-fades
func warm_room(name: StringName) -> void:
	if not _enabled or name == &"" or name == _room_now:
		return
	var path := ROOM_WAV % name
	if not ResourceLoader.exists(path):
		path = ROOM_PATH % name
	if ResourceLoader.exists(path) and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path)


## Loop one frame short of the end, as PCM: full count and QOA click at every lap.
## Why: docs/why/Audio.md#room-tone-loops
static func loop_whole(w: AudioStreamWAV) -> void:
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = roundi(w.get_length() * float(w.mix_rate)) - 1


func room(name: StringName, fade_s: float = ROOM_FADE) -> void:
	if not _enabled or name == _room_now:
		return
	_room_now = name
	if _room_fade != null and _room_fade.is_valid():
		_room_fade.kill()
	if name == &"":
		if _room == null or not _room.playing:
			return
		_room_fade = create_tween()
		_room_fade.tween_property(_room, ^"volume_db", OFF_DB, fade_s)
		_room_fade.tween_callback(_room.stop)
		_load_pa(&"")
		return
	var path := ROOM_WAV % name
	if not ResourceLoader.exists(path):
		path = ROOM_PATH % name
	var stream: AudioStream = load(path)
	if stream == null:
		push_warning("Audio: missing room tone %s" % name)
		_room_now = &""
		return
	# Both stream kinds need telling to loop on their own length, each asked differently.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		loop_whole(stream as AudioStreamWAV)
	_load_pa(name)
	if _room == null:
		_room = AudioStreamPlayer.new()
		_room.bus = &"Ambient"
		add_child(_room)
	_room.stream = stream
	_room.volume_db = OFF_DB
	_room.play()
	_room_fade = create_tween()
	_room_fade.tween_property(_room, ^"volume_db",
			float(ROOM_LEVELS.get(name, ROOM_DB)), fade_s)


## Loop position as heard (player position, mix time, latency); -1 if the room is not playing.
func room_clock(name: StringName) -> float:
	if _room == null or not _room.playing or _room_now != name:
		return -1.0
	return _room.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()


## The game deals the PA lines: a baked mixdown cannot be shuffled, and Jon asked for random order.
## Why: docs/why/Audio.md#station-pa
func _load_pa(name: StringName) -> void:
	_pa_lines = []
	_pa_bag = []
	_pa_next = 0.0
	var path := "res://assets/audio/ambience/%s.json" % name
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_ARRAY:
		push_warning("Audio: %s is not a list of lines" % path)
		return
	_pa_lines = data as Array
	# NOT IMMEDIATELY. Arriving at a station and being talked at on the same
	# frame reads as a cutscene; the first line lands once you are standing there.
	_pa_next = randf_range(PA_FIRST.x, PA_FIRST.y)


## A bag, not a roll: random draws would repeat about one dock in eight.
func _deal_pa() -> void:
	if _pa_lines.is_empty():
		return
	if _pa_bag.is_empty():
		for i in _pa_lines.size():
			_pa_bag.append(i)
		_pa_bag.shuffle()
	var idx: int = _pa_bag.pop_back()
	var row := _pa_lines[idx] as Dictionary
	var stream: AudioStream = load("res://assets/audio/ambience/%s.ogg"
			% String(row.get("name", "")))
	if stream == null:
		return
	if _pa == null:
		_pa = AudioStreamPlayer.new()
		# THE SAME BUS AND THE SAME LEVEL AS THE BED IT CAME OUT OF, so the
		# announcement sits where it always sat against the crowd.
		_pa.bus = &"Ambient"
		add_child(_pa)
	_pa.stream = stream
	_pa.volume_db = float(ROOM_LEVELS.get(&"amb_station", ROOM_DB))
	_pa.play()
	_pa_next = float(row.get("secs", 10.0)) + randf_range(PA_GAP.x, PA_GAP.y)


## Is the station mid-sentence right now? The music steps aside for it, and
## that is the whole reason this is asked every frame.
func _room_talking() -> bool:
	return _pa != null and _pa.playing





## The fade is an argument as the quit needs a shorter one than a swap's 2.5 s.
## Why: docs/why/Audio.md#music-fade-out
func stop_music(secs: float = SWAP) -> void:
	if not _enabled:
		return
	_cue = &""
	for i in _mv.size():
		_ramp(i, 0.0, secs)


## Pitch bends down on every voice, room included. One way only: just the quit calls it.
## Why: docs/why/Audio.md#power-down
func power_down(secs: float, to: float = 0.30) -> void:
	if not _enabled:
		return
	var t := create_tween().set_parallel(true)
	for p: AudioStreamPlayer in _mv:
		# EASE_IN, so it holds pitch for a moment and then goes. Linear from the
		# first frame sounds like a tape being scrubbed; a machine coasts down.
		t.tween_property(p, ^"pitch_scale", to, secs) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _room != null:
		t.tween_property(_room, ^"pitch_scale", to, secs) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## ---------------- the two voices ----------------
## Two players only: one carries the cue, the other is free for the crossfade.
## Why: docs/why/Audio.md#music-voices

func _voices() -> void:
	if not _mv.is_empty():
		return
	for _i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = &"Music"
		p.volume_db = OFF_DB
		p.set_meta(&"g", 0.0)
		add_child(p)
		_mv.append(p)
		_mfade.append(null)

## Bring `stream` up on the free voice and take the other down.
func _swap_to(stream: AudioStream, secs: float) -> void:
	_voices()
	var nxt := 0 if _now != 0 else 1
	var p: AudioStreamPlayer = _mv[nxt]
	p.stream = stream
	p.set_meta(&"g", 0.0)
	p.volume_db = OFF_DB
	p.play()
	_ramp(nxt, db_to_linear(MUSIC_DB), secs)
	if _now >= 0:
		_ramp(_now, 0.0, secs)
	_now = nxt

## The next pass starts on the other voice; this one rings its reverb tail over the downbeat.
func _relay() -> void:
	var p: AudioStreamPlayer = _mv[_now]
	var nxt := 0 if _now != 0 else 1
	var o: AudioStreamPlayer = _mv[nxt]
	o.stream = p.stream
	# The fallback is the cue level, not 1.0 -- full scale is no longer unity.
	o.set_meta(&"g", float(p.get_meta(&"g", db_to_linear(MUSIC_DB))))
	o.play()
	var gone := _now
	_now = nxt
	# The outgoing voice keeps its level and simply runs out of file. Held in `_mfade`, so a
	# cue change that reuses this voice inside the tail kills the stop instead of eating the cue.
	var t := create_tween()
	t.tween_interval(TAIL)
	t.tween_callback(p.stop)
	_mfade[gone] = t

func _ramp(i: int, to: float, secs: float) -> void:
	var p: AudioStreamPlayer = _mv[i]
	var old: Tween = _mfade[i]
	if old != null and old.is_valid():
		old.kill()
	var t := create_tween()
	t.tween_method(func(v: float) -> void: p.set_meta(&"g", v),
			float(p.get_meta(&"g", 0.0)), to, secs)
	if to <= 0.0:
		t.tween_callback(p.stop)
	_mfade[i] = t

## The music steps back for a set piece on the same eased duck as an announcement.
var _scene_duck_until := -1.0
var _scene_duck_to := 1.0

func duck_music(amount: float, secs: float) -> void:
	_scene_duck_to = clampf(1.0 - amount, 0.05, 1.0)
	_scene_duck_until = GameClock.now() + secs


## No stinger exists since Jon cut the old ones; the ask is counted and taped.
var stingers_asked := 0

func music_stinger(strength: float) -> void:
	stingers_asked += 1
	if taping:
		tape.append([&"music_stinger", Time.get_ticks_msec(), linear_to_db(maxf(0.01, strength)), 1.0])


func cue() -> StringName:
	return _cue


# ---------------- A.S.H.'s voice ----------------
# One line at a time on its own player, SFX bus, ogg since a line never loops.
# Why: docs/why/Audio.md#ash-voice
const VOICE_DB := -4.0
## The score ducks -4 dB for her line, asked every frame so a cut line lets the music up.
const VOICE_DUCK_DB := -4.0
## A cut line's fade, ms: under a frame and a half at 60, and long enough that
## the stream lands on zero rather than clicking (`hush`'s reasoning).
const VOICE_CUT_MS := 60
var _voice: AudioStreamPlayer = null
var _voice_fade: Tween = null
## What she is saying now, as a harness reads it (headless has no player, so
## this is the account): the file, and the game second it runs out.
var voice_now := ""
var _voice_end := 0.0
## Where her line glitches, planned headless too so a harness can read it.
var voice_glitches: Array = []
## The glitched take is baked off the main thread: decode and edit cost up to 19 ms.
## Why: docs/why/Audio.md#ash-voice
var _prep := {}
## Workers whose take was not wanted any more, waited on once they are done.
var _reap: Array[int] = []
## What the last line cost the main thread to start, usec, and whether it was
## heard glitched: for `-- sheet=LowHullTest`.
var voice_start_usec := 0
var voice_heard_glitched := false
## Harness hooks: bake even where nothing plays (headless), and pretend the
## worker is not done yet (the fallback).
var bake_headless := false
var bake_hold := false


## Her line at `path` is coming (her power-on has begun): plan its glitches
## now, and if it has any, start making the glitched take on a worker.
func ash_voice_prepare(path: String) -> void:
	_drop_prep()
	var stream := load(path) as AudioStream if ResourceLoader.exists(path) else null
	if stream == null:
		return
	var plan := LowHull.voice_plan(stream.get_length())
	_prep = {path = path, plan = plan, task = -1, out = [], sr = AudioServer.get_mix_rate()}
	if plan.is_empty() or not (_enabled or bake_headless):
		return
	# the playback is made here, on the main thread; the worker only reads it
	var pb := stream.instantiate_playback()
	if pb == null:
		return
	var secs := stream.get_length()
	var sr: float = _prep.sr
	var out: Array = _prep.out
	var plan_copy := plan.duplicate(true)
	var job := func() -> void:
		var r := VoiceGlitch.bake_placed(pb, secs, sr, plan_copy)
		out.append(r.pcm)
		out.append(r.plan)
	_prep.task = WorkerThreadPool.add_task(job, false, "ash voice glitch")


## A prepared take nobody will say: its worker reaped when it is done.
func _drop_prep() -> void:
	if int(_prep.get("task", -1)) >= 0:
		_reap.append(int(_prep.task))
	_prep = {}


func _reap_done() -> void:
	for i in range(_reap.size() - 1, -1, -1):
		if WorkerThreadPool.is_task_completed(_reap[i]):
			WorkerThreadPool.wait_for_task_completion(_reap[i])
			_reap.remove_at(i)


## Taped as `ash/<name>` even headless, where nothing plays, so tests read the tape.
func ash_voice(path: String) -> float:
	var stream := load(path) as AudioStream if ResourceLoader.exists(path) else null
	if stream == null:
		push_warning("Audio: missing voice %s" % path)
		return 0.0
	var secs := stream.get_length()
	voice_now = path
	_voice_end = GameClock.now() + secs
	var t0 := Time.get_ticks_usec()
	# the glitched take, if its worker is done; otherwise the clean one
	var glitched: AudioStream = null
	voice_glitches = []
	if String(_prep.get("path", "")) == path:
		var task := int(_prep.task)
		if task < 0:
			# nothing baked: planned only where nothing plays (a harness reads it)
			if not _enabled and not bake_headless:
				voice_glitches = _prep.plan
		elif WorkerThreadPool.is_task_completed(task) and not bake_hold:
			WorkerThreadPool.wait_for_task_completion(task)
			_prep.task = -1
			if not (_prep.out as Array).is_empty():
				glitched = VoiceGlitch.from_pcm(_prep.out[0], float(_prep.sr))
			if glitched != null:
				# where the worker moved them onto her words (`VoiceGlitch.place`)
				voice_glitches = _prep.out[1] if (_prep.out as Array).size() > 1 else _prep.plan
	_drop_prep()
	voice_heard_glitched = glitched != null
	voice_start_usec = Time.get_ticks_usec() - t0
	if taping:
		tape.append([StringName("ash/" + path.get_file().get_basename()), Time.get_ticks_msec(), VOICE_DB, 1.0])
	if not _enabled:
		return secs
	if _voice == null:
		_voice = AudioStreamPlayer.new()
		_voice.bus = &"SFX"
		add_child(_voice)
	if _voice_fade != null and _voice_fade.is_valid():
		_voice_fade.kill()
	_voice_fade = null
	# the same take with its glitches in, the same length to the sample
	_voice.stream = glitched if glitched != null else stream
	_voice.volume_db = VOICE_DB
	_voice.pitch_scale = 1.0
	_voice.play()
	return secs


## Stop her line, faded over `fade_ms` (her words were cut: a hint, END TURN,
## the ship lost, Settings).
func ash_voice_stop(fade_ms: int = VOICE_CUT_MS) -> void:
	if not ash_speaking():
		voice_now = ""
		return
	voice_now = ""
	if taping:
		tape.append([&"ash/stop", Time.get_ticks_msec(), 0.0, 1.0])
	if not _enabled or _voice == null or not _voice.playing:
		return
	if _voice_fade != null and _voice_fade.is_valid():
		return
	_voice_fade = create_tween()
	_voice_fade.tween_property(_voice, "volume_db", _voice.volume_db - 40.0, fade_ms / 1000.0)
	_voice_fade.tween_callback(_voice.stop)


## A line of hers is sounding (or, headless, would be).
func ash_speaking() -> bool:
	if voice_now != "" and GameClock.now() >= _voice_end:
		voice_now = ""
	if _enabled and _voice != null:
		return _voice.playing and voice_now != ""
	return voice_now != ""


func _process(delta: float) -> void:
	_fx_tick()
	if not _reap.is_empty():
		_reap_done()
	if not _enabled:
		return
	# Asked every frame off the playhead, not on events, so tabbing away cannot stick the duck.
	# Why: docs/why/Audio.md#station-duck
	if _room_now == &"amb_station" and not _pa_lines.is_empty():
		_pa_next -= delta
		if _pa_next <= 0.0:
			_deal_pa()
	elif _pa != null and _pa.playing:
		_pa.stop()
	var duck_to: float = db_to_linear(DUCK_DB) if _room_talking() else 1.0
	# A.S.H. talking (`ash_voice`)
	if ash_speaking():
		duck_to = minf(duck_to, db_to_linear(VOICE_DUCK_DB))
	# a boss's death holds the music down for its set piece (`duck_music`)
	if GameClock.now() < _scene_duck_until:
		duck_to = minf(duck_to, _scene_duck_to)
	_duck = move_toward(_duck, duck_to,
			delta / (DUCK_IN if duck_to < _duck else DUCK_OUT))
	# The room itself, on the same clock as the room's own fade so the music
	# steps back as the station arrives rather than a beat after it.
	var room_to: float = float(ROOM_DUCKS.get(_room_now, 1.0))
	_rduck = move_toward(_rduck, room_to, delta / ROOM_DUCK_S)
	for i in _mv.size():
		var p: AudioStreamPlayer = _mv[i]
		var g := float(p.get_meta(&"g", 0.0)) * _duck * _rduck
		p.volume_db = OFF_DB if g <= 0.0005 else linear_to_db(g)
	# The loop point, watched on the voice that currently carries the cue.
	# The death cue is exempt: it plays once and is allowed to run out.
	var loops := _cue != &"" and not _cue in ONE_SHOT and _loop_of(_cue) > 0.0
	if _now >= 0 and loops:
		var cur: AudioStreamPlayer = _mv[_now]
		if cur.playing and cur.get_playback_position() >= _loop_of(_cue):
			_relay()

## Loop seconds for a cue, from the sidecar, read once.
func _loop_of(cue: StringName) -> float:
	if _loops.is_empty():
		_load_loops()
	return float(_loops.get(cue, 0.0))

func _load_loops() -> void:
	_loops = {&"": 0.0}                  ## non-empty, so a failure is not retried
	if not FileAccess.file_exists(LOOPS_PATH):
		push_warning("Audio: %s is missing, cues will not loop" % LOOPS_PATH)
		return
	var data: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(LOOPS_PATH))
	if typeof(data) != TYPE_ARRAY:
		push_warning("Audio: %s is not readable" % LOOPS_PATH)
		return
	for row: Variant in data as Array:
		var d := row as Dictionary
		var ogg := str(d.get("ogg", ""))
		if ogg.ends_with(".ogg"):
			var id := StringName(ogg.substr(0, ogg.length() - 4))
			_loops[id] = float(d.get("loop_seconds", 0.0))

# ---------------- sound effects ----------------

## One voice per hold or hull action, as data: three screens had drifted apart.
const ACT_SFX: Dictionary = {
	&"module_install": 0.04,
	&"module_uninstall": 0.05,
	&"module_scrap": 0.05,
	&"hull_transfer": 0.03,
}

func act(name: StringName) -> void:
	play(name, float(ACT_SFX.get(name, 0.06)))


## `db` is an offset so a reward sting can be turned down without authoring a second file.
## Why: docs/why/Audio.md#play-parameters
func play(name: StringName, pitch_var: float = 0.06, limit_ms: int = 0,
		db: float = 0.0, pitch: float = 1.0, from: float = 0.0, exact: bool = false) -> void:
	# (headless there is no sound, but a harness taping still gets the decision:
	# everything below down to the pick, then `_dry_play`)
	if not _enabled and not taping:
		return
	var now := Time.get_ticks_msec()
	# Suppression is not a rate limit: it must be checked without a limit too, or `jump` leaked.
	# Why: docs/why/Audio.md#suppression
	if int(_last.get(name, 0)) > now:
		return
	if limit_ms > 0 and now - int(_last.get(name, -limit_ms)) < limit_ms:
		return
	_last[name] = now
	# Round robins: `name_2.wav`, `name_3.wav` play a random take; one file reads as a toy.
	var pick := name
	# `exact`: this take and no other (a pool that levels its takes one by one,
	# `Audio.FX` `pool`, names each; `explosion_small` alone would round-robin)
	var vars: Array = [name] if exact else _variants.get(name, [])
	if vars.is_empty() and not _variants.has(name):
		vars = [name]
		# Scan up to `_16`: a scan that stops short drops the extra takes silently.
		for i in range(2, 17):
			var vn := StringName("%s_%d" % [name, i])
			if ResourceLoader.exists(SFX_PATH % vn):
				vars.append(vn)
		_variants[name] = vars
	if vars.size() > 1:
		pick = vars[randi() % vars.size()]
	if not _enabled:
		_dry_play(pick, name, db, pitch * (1.0 + randf_range(-pitch_var, pitch_var)), from)
		return
	var stream: AudioStream = _cache.get(pick)
	if stream == null:
		stream = load(SFX_PATH % pick)
		if stream == null:
			push_warning("Audio: missing sfx %s" % pick)
			return
		_cache[pick] = stream
	# Round-robin the pool. Fourteen voices is more than the game ever asks
	# for at once; stealing the oldest is the right failure if it ever does.
	var p := _sfx[_sfx_next]
	# Kill a hush tween on a reused voice, or the new sound fades out underneath itself.
	if _fade[_sfx_next] != null and _fade[_sfx_next].is_valid():
		_fade[_sfx_next].kill()
	_fade[_sfx_next] = null
	_sfx_next = (_sfx_next + 1) % _sfx.size()
	p.stream = stream
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_var, pitch_var))
	p.volume_db = db
	# Store the pick, not the asked name, so a hush naming either one lands.
	p.set_meta(&"cue", pick)
	p.set_meta(&"asked", name)
	p.set_meta(&"t0", Time.get_ticks_msec())
	if taping:
		tape.append([pick, Time.get_ticks_msec(), db, p.pitch_scale, GameClock.now(),
			Engine.get_process_frames(), name, from])
	p.play(from)

## Holds a name quiet when a screen plays its own better-informed sound for the same change.
func suppress(name: StringName, ms: int = 400) -> void:
	_last[name] = Time.get_ticks_msec() + ms


## The other half of `suppress`: fades sounds already playing, as a cut stream clicks.
## Why: docs/why/Audio.md#hush
func hush(names: Array[StringName], fade_ms: int = 120) -> void:
	# (taped as asked, so a headless test sees what would be cut: `hushed`)
	if taping:
		hushed.append([names.duplicate(), Engine.get_process_frames()])
	if not _enabled:
		return
	for i in _sfx.size():
		var p := _sfx[i]
		if not p.playing:
			continue
		if not (names.has(p.get_meta(&"cue", &"")) \
				or names.has(p.get_meta(&"asked", &""))):
			continue
		if _fade[i] != null and _fade[i].is_valid():
			continue                      ## already on its way out
		var t := create_tween()
		t.tween_property(p, "volume_db", p.volume_db - 40.0, fade_ms / 1000.0)
		t.tween_callback(p.stop)
		_fade[i] = t

## Caps stacked blips by fading the oldest, keeping the rhythm Jon picked on the audition page.
## Why: docs/why/Audio.md#capped-sounds
func play_capped(name: StringName, pitch_var: float, cap: int, db: float = 0.0,
		steal_ms: int = 25, from: float = 0.0) -> void:
	if not _enabled:
		if taping:
			_dry_steal(name, cap)
			play(name, pitch_var, 0, db, 1.0, from)
		return
	var live: Array[int] = []
	for i in _sfx.size():
		var p := _sfx[i]
		if p.playing and p.get_meta(&"asked", &"") == name 				and not (_fade[i] != null and _fade[i].is_valid()):
			live.append(i)
	live.sort_custom(func(a: int, b: int) -> bool:
		return int(_sfx[a].get_meta(&"t0", 0)) < int(_sfx[b].get_meta(&"t0", 0)))
	while live.size() >= maxi(cap, 1):
		var i: int = live.pop_front()
		var p := _sfx[i]
		var t := create_tween()
		t.tween_property(p, "volume_db", p.volume_db - 40.0, steal_ms / 1000.0)
		t.tween_callback(p.stop)
		_fade[i] = t
	play(name, pitch_var, 0, db, 1.0, from)

func click() -> void:   play(&"ui_click", 0.05)
func hover() -> void:   play(&"ui_hover", 0.09, 40)
func back() -> void:    play(&"ui_back", 0.03)
## Settings' volume check is the only caller; it plays a sound the game already makes.
func confirm() -> void: play(&"ui_click", 0.02)
func denied() -> void:  play(&"ui_denied", 0.03)

## THE LAB'S GLASS (Jon's picks, Nov 7: hover h2_03, login l2_05), at 0 dB: the files carry
## their level. `lab_hover`: the pointer arriving on the glass.
## Why: docs/why/Audio.md#the-labs-glass
func lab_hover() -> void: play(&"lab_glass_hover", 0.02, 120)
## `lab_login`: the press that signs in (`StationScreen._open_lab`), from the
## file's start (Jon's offset 0), its swell peaking ~0.55 s into the camera's
## 0.9 s move onto the glass and its two notes after.
func lab_login() -> void: play(&"lab_login", 0.0)
## `lab_research_buy`: a step bought on the research board (`LabZoom._on_buy`), on the
## press, as the board's 1.5 s flash starts (Jon's pick C15, Nov 9: punch tape and two
## beeps). At 0 dB: the file carries its level, matched to `lab_login`.
func lab_research_buy() -> void: play(&"lab_research_buy", 0.0)


# ---------------- the effects' moments ----------------
# One switchable row per moment, played on the frame its picture acts.
# Why: docs/why/Audio.md#effect-moments
const FX: Dictionary = {
	# A ship's death is three layers levelled to the hit: the kill takes spread 5 dB (Jon, Oct 19).
	# Why: docs/why/Audio.md#kill-boom
	&"kill_boom": {pick = {pool = [[&"explosion_small_3", -0.9], [&"explosion_small_4", 2.1],
				[&"explosion_small_5", -0.2]], db = 0.0, limit = 0.2, pitch = 0.05},
			before = {file = &"explosion_small", db = 0.0, pitch = 0.09}},
	&"kill_thump": {pick = {pool = [[&"impact_hull", 0.0]], db = -6.0, limit = 0.2, pitch = 0.03}, before = {}},
	&"kill_crunch": {pick = {file = &"hull_crunch", db = -4.0, limit = 0.2, pitch = 0.05}, before = {}},
	&"kill_pop": {pick = {pool = [[&"explosion_small", 0.0], [&"explosion_small_2", -0.4]], db = -3.0, limit = 0.12, pitch = 0.08},
			before = {file = &"explosion_small", db = -6.0, pitch = 0.09}},
	# Creature deaths N, O and P play on the first beat; only ship breakups said `broke`.
	&"fauna_death": {pick = {file = &"fauna_falls", db = -4.0, limit = 0.4}, before = {}},
	# Plating going on: a bolt driver's bangs and a latch, the latch landing as the clamp.
	&"brace_on": {pick = {file = &"brace_on", db = 0.0, at = &"bolt_on", limit = 0.09, pitch = 0.03},
			free = {file = &"module_install", db = 0.0, at = &"bolt_on", limit = 0.09, pitch = 0.04},
			before = {file = &"shield_block", db = -8.0, at = &"clamp", limit = 0.09, pitch = 0.06}},
	&"brace_on_yours": {pick = {file = &"brace_on", db = 0.0, at = &"bolt_on", limit = 0.09, pitch = 0.03},
			free = {file = &"module_install", db = 0.0, at = &"bolt_on", limit = 0.09, pitch = 0.04},
			before = {file = &"shield_block", db = 0.0, at = &"card", pitch = 0.06}},
	# PLATES TUMBLING OFF: something thrown off a hull (-14 LUFS, so down 10).
	# Jon picked no bought take for it.
	&"brace_off": {pick = {file = &"jettison", db = -10.0, limit = 0.25}, before = {}},
	# A HIT PARTLY TAKEN BY BLOCK OR BRACE: the armour ringing under the impact,
	# Jon's A1 and A2 in turn (the free pass: shield_block -8).
	&"hit_partial": {pick = {file = &"brace_clang", db = 0.0, limit = 0.09, pitch = 0.04},
			free = {file = &"shield_block", db = -8.0, limit = 0.09, pitch = 0.06}, before = {}},
	# Gas leaving the hull: vent jets and sputters, never closer than 0.4 s apart.
	&"vent_jet": {pick = {file = &"gas_vent", db = 0.0, limit = 0.15},
			free = {file = &"vent", db = -8.0, limit = 0.15}, before = {}},
	&"vent_hiss": {pick = {file = &"gas_vent", db = 0.0, limit = 0.15},
			free = {file = &"vent", db = -8.0, limit = 0.15}, before = {}},
	&"vent_sputter": {pick = {file = &"gas_puff", db = 0.0, limit = 0.4, cap = 1},
			free = {file = &"vent", db = -12.0, limit = 0.4, cap = 1}, before = {}},
	# THE SIDE BAR DECODING: a blip as each line starts to resolve, the event
	# text's own, at most two in the air.
	&"side_decode": {pick = {file = &"text_blip", db = 0.0, cap = 2, pitch = 0.06}, before = {}},
	# THE CHROME SLIDING: the escape menu's drawer sounds, down 6 for every hop.
	&"chrome_on": {pick = {file = &"menu_open", db = -6.0, pitch = 0.03}, before = {}},
	&"chrome_off": {pick = {file = &"menu_close", db = -6.0, pitch = 0.03}, before = {}},
	# The fight's band uses the esc menu's open and close sounds, at Jon's ask.
	&"fight_band": {pick = {file = &"menu_open", db = 0.0, pitch = 0.03},
			free = {file = &"hold_lift", db = -4.0, pitch = 0.03}, before = {}},
	&"fight_band_down": {pick = {file = &"menu_close", db = 0.0, pitch = 0.03}, before = {}},
	# Your ship lost: the set goes off as the picture goes, with no page click on the swap.
	&"loss_handoff": {pick = {file = &"power_off", db = 0.0, pitch = 0.0}, before = {}},
	&"loss_duck": {pick = {duck = 0.6}, before = {}},
	&"loss_swap": {pick = {hush = &"ui_tab"}, before = {}},
	&"charge_prelude": {pick = {file = &"charge_whine", db = 0.0, offset = 0.7, limit = 3.0, pitch = 0.0}, before = {}},
	# THE HELLBENDER HEATING: the red hypergiant's furnace, faded in as the
	# device heats (1.5 s) and out as it bursts (5.6 s).
	&"hb_heat": {pick = {bed = &"amb_red", db = -13.0, fade_in = 0.6, fade_out = 0.4, at = &"emblem_heat"}, before = {}},
	# The bosses' small breaks: the low kill pool, glass cracks and a shatter for the Custodian.
	&"boss_pop": {pick = {file = &"explosion_small", db = -10.0, limit = 0.08, pitch = 0.09}, before = {}},
	&"spine_pop": {pick = {file = &"glass_crack", db = 0.0, limit = 0.08, pitch = 0.06},
			free = {file = &"explosion_small", db = -10.0, limit = 0.08, pitch = 0.09}, before = {}},
	&"boss_split": {pick = {file = &"glass_shatter", db = 0.0, pitch = 0.0},
			free = {file = &"explosion_small", db = 0.0, pitch = 0.09}, before = {}},
	# Shield at rest: one hum however many ships hold a shield, as it is the same field.
	&"shield_idle": {pick = {bed = &"shield_idle_bed", db = 0.0, fade_in = 0.3, fade_out = 0.3}, before = {}},
	# ITS RIPPLES AND GLITCHES (about 43 a minute a shield): a crackle (Jon's
	# shield_glitch A1, -36), never closer than half a second, one at a time.
	&"shield_glitch": {pick = {file = &"shield_glitch", db = 0.0, limit = 0.5, cap = 1, pitch = 0.08}, before = {}},
	# A hull buckling: crunch takes on their own grid, and a crack under a hit's impact.
	&"crumple": {pick = {file = &"hull_crunch", db = 0.0, limit = 0.1, pitch = 0.05}, before = {}},
	&"crack_mark": {pick = {file = &"hull_crunch", db = -6.0, limit = 0.3, pitch = 0.06}, before = {}},
	# A charge whines up into its blast, started so it runs out as the blast lands.
	&"charge": {pick = {file = &"charge_whine", db = 0.0, end_on = true, limit = 0.3, pitch = 0.02}, before = {}},
	# HEAT (Jon's heat_sizzle A1, -28): L's melt and B's embers; and a hit's
	# scorch or heat bloom, under its impact (down 6, and half a second apart).
	&"heat": {pick = {file = &"heat_sizzle", db = 0.0, limit = 0.5, pitch = 0.03}, before = {}},
	&"heat_mark": {pick = {file = &"heat_sizzle", db = -6.0, limit = 0.6, pitch = 0.06}, before = {}},
	# DEATH I DISSOLVING (Jon's dissolve_fizz B1), which was silent.
	&"dissolve": {pick = {file = &"dissolve_fizz", db = 0.0, pitch = 0.02}, before = {}},
	# A PULL INWARD (Jon's gravity_collapse B1, a reverse whoosh cut dead): death
	# J's pull into its collapse and C1b's crush into its blast, ending on it.
	&"collapse": {pick = {file = &"gravity_collapse", db = 0.0, end_on = true, pitch = 0.0}, before = {}},
	# Glass cracking: the Custodian's cracks, a shield shattering and a creature's scales shedding.
	&"cust_crack": {pick = {file = &"glass_crack", db = 0.0, limit = 0.1, pitch = 0.05}, before = {}},
	&"k_shatter": {pick = {file = &"glass_crack", db = 0.0, pitch = 0.03}, before = {}},
	&"shed": {pick = {file = &"glass_crack", db = -6.0, limit = 0.3, pitch = 0.08}, before = {}},
	# THE CUSTODIAN'S BEAMS (Jon's unstable_arc A1, a PCM loop): up with the
	# first beam, down as they shrink into the crush.
	&"arc": {pick = {bed = &"unstable_arc", db = 0.0, fade_in = 0.15, fade_out = 0.35}, before = {}},
	# AND ITS CENTRE SWELLING (Jon's boss_riser A1), into the crush or the
	# implode. The plan put charge_whine on this swell too; one riser is enough.
	&"riser": {pick = {file = &"boss_riser", db = 0.0, end_on = true, pitch = 0.0}, before = {}},
}

## row -> &"pick" (the default), &"before", &"off", or a take of its own.
var fx_choice: Dictionary = {}
## While `taping`: every row that sounded, [row, kind, file, db, frame, game s].
var fx_heard: Array = []
var _tape_to := ""


func _exit_tree() -> void:
	if _tape_to == "":
		return
	var f := FileAccess.open(_tape_to, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({tape = tape, fx = fx_heard,
			frame_offset = Engine.get_frames_drawn() - Engine.get_process_frames()}))
		f.close()
var _fx_last: Dictionary = {}       ## row -> game s it last sounded
var _fx_due: Array = []             ## [game s, row, take, kind, secs]


## The take a row plays now ({} for silence).
func fx_take(row: StringName) -> Dictionary:
	var c: Variant = fx_choice.get(row, &"pick")
	var r: Dictionary = FX.get(row, {})
	if c is Dictionary:
		# a file of its own, with the pick's timing unless it says otherwise
		var t: Dictionary = (r.get(&"pick", {}) as Dictionary).duplicate()
		for k: StringName in [&"file", &"bed", &"duck", &"hush"]:
			t.erase(k)
		t.merge(c as Dictionary, true)
		return t
	if c == &"off":
		return {}
	if c == &"free":
		return r.get(&"free", r.get(&"pick", {}))
	return r.get(c, {})


## Choose for a row: &"pick", &"free", &"before", &"off", or "file@db[@offset]".
func fx_choose(row: StringName, choice: String) -> void:
	if choice in ["pick", "free", "before", "off"]:
		fx_choice[row] = StringName(choice)
		return
	var bits := choice.split("@")
	var t := {file = StringName(bits[0])}
	if bits.size() > 1 and bits[1].is_valid_float():
		t.db = float(bits[1])
	if bits.size() > 2 and bits[2].is_valid_float():
		t.offset = float(bits[2])
	fx_choice[row] = t


## `fx=row:choice,row:choice` (`all:` for every row).
func _fx_args(spec: String) -> void:
	for part in spec.split(",", false):
		var kv := part.split(":")
		if kv.size() != 2:
			continue
		var rows: Array = FX.keys() if kv[0] == "all" else [StringName(kv[0])]
		for row: StringName in rows:
			fx_choose(row, kv[1])


## `row`'s moment has happened on screen this frame; `kind` and `secs` come from the picture.
func fx(row: StringName, kind: StringName = &"", secs: float = 0.0) -> bool:
	var take := fx_take(row)
	if take.is_empty():
		return false
	if take.has(&"at") and StringName(take.at) != kind:
		return false
	var now := GameClock.now()
	var lim := float(take.get(&"limit", 0.0))
	if lim > 0.0 and now - float(_fx_last.get(row, -1e9)) < lim - 0.0001:
		return false
	_fx_last[row] = now
	var off := float(take.get(&"offset", 0.0))
	if off > 0.0:
		_fx_due.append([now + off, row, take, kind, secs])
		return true
	_fx_do(row, take, kind, secs)
	return true


func _fx_do(row: StringName, take: Dictionary, kind: StringName, secs: float) -> void:
	var file: StringName = take.get(&"file", &"")
	var db := float(take.get(&"db", 0.0))
	# A POOL OF TAKES, EACH AT ITS OWN LEVEL: one drawn at random, played as
	# itself (not round-robined), its own offset on the row's level
	var exact := false
	if take.has(&"pool"):
		var pool: Array = take.pool
		var one: Array = pool[randi() % pool.size()]
		file = StringName(one[0])
		db += float(one[1])
		exact = true
	if taping:
		fx_heard.append([row, kind, file if file != &"" else StringName(take.get(&"bed",
			take.get(&"hush", &"duck" if take.has(&"duck") else &""))), db,
			Engine.get_process_frames(), GameClock.now()])
	if take.has(&"hush"):
		suppress(StringName(take.hush), 400)
	if take.has(&"duck"):
		duck_music(float(take.duck), secs)
	if take.has(&"bed"):
		_bed_on(row, take)
	if file == &"":
		return
	var pv := float(take.get(&"pitch", 0.05))
	var from := maxf(0.0, -float(take.get(&"offset", 0.0)))
	# ENDS ON THE MOMENT'S END: started that far into the file, so it runs out
	# as the beat it leads up to lands (a charge's whine into its blast)
	if bool(take.get(&"end_on", false)) and secs > 0.0:
		from = maxf(from, _len_of(file) - secs)
	var cap := int(take.get(&"cap", 0))
	if cap > 0:
		play_capped(file, pv, cap, db, 25, from)
	else:
		play(file, pv, 0, db, 1.0, from, exact)


## Delayed takes (`offset` > 0), on the game's clock: a film runs them at its
## own speed and slow motion reaches them.
func _fx_tick() -> void:
	if _fx_due.is_empty():
		return
	var now := GameClock.now()
	var keep: Array = []
	for d: Array in _fx_due:
		if now >= float(d[0]):
			_fx_do(d[1], d[2], d[3], float(d[4]))
		else:
			keep.append(d)
	_fx_due = keep


## ---- beds: loops under what the picture holds (`bed` rows)
## One player a row, so each bed is its own and none cuts another off.
## Why: docs/why/Audio.md#beds
var _beds: Dictionary = {}		  ## row -> AudioStreamPlayer
var _bed_tws: Dictionary = {}	   ## row -> Tween
## the rows whose bed is up (kept headless too, for a harness)
var beds_on: Dictionary = {}
## the last row brought up and still up, or &"" (for a harness)
var bed_now: StringName = &""


func _bed_on(row: StringName, take: Dictionary) -> void:
	beds_on[row] = true
	bed_now = row
	if not _enabled:
		return
	var path := ROOM_WAV % StringName(take.bed)
	if not ResourceLoader.exists(path):
		path = SFX_PATH % StringName(take.bed)
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStreamWAV
	if stream == null:
		return
	# (a room's loop, as `room` loops it: the same file, the same seam)
	loop_whole(stream)
	var pl: AudioStreamPlayer = _beds.get(row)
	if pl == null:
		pl = AudioStreamPlayer.new()
		pl.bus = &"SFX"
		add_child(pl)
		_beds[row] = pl
	var old: Tween = _bed_tws.get(row)
	if old != null and old.is_valid():
		old.kill()
	pl.stream = stream
	pl.volume_db = OFF_DB
	pl.play()
	var tw := create_tween()
	tw.tween_property(pl, ^"volume_db", float(take.get(&"db", 0.0)),
		maxf(0.01, float(take.get(&"fade_in", 0.5)))).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_bed_tws[row] = tw


## The set piece a bed was under has done what the bed was for (or is gone).
func fx_stop(row: StringName) -> void:
	if not beds_on.has(row):
		return
	beds_on.erase(row)
	if bed_now == row:
		bed_now = &""
	if taping:
		fx_heard.append([row, &"stop", &"", 0.0, Engine.get_process_frames(), GameClock.now()])
	var pl: AudioStreamPlayer = _beds.get(row)
	if pl == null or not pl.playing:
		return
	var take := fx_take(row)
	var old: Tween = _bed_tws.get(row)
	if old != null and old.is_valid():
		old.kill()
	var tw := create_tween()
	tw.tween_property(pl, ^"volume_db", OFF_DB,
		maxf(0.01, float(take.get(&"fade_out", 0.4)))).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(pl.stop)
	_bed_tws[row] = tw


## A bed that follows a state the picture shows every frame (a shield up and
## seen): up while `on`, down when not. Asked each frame; acts on the edges.
func fx_hold(row: StringName, on: bool, kind: StringName = &"") -> void:
	if on and not beds_on.has(row):
		fx(row, kind)
	elif not on and beds_on.has(row):
		fx_stop(row)


## A file's length, s (its first take), or 0.
func _len_of(file: StringName) -> float:
	var stream: AudioStream = _cache.get(file)
	if stream == null and ResourceLoader.exists(SFX_PATH % file):
		stream = load(SFX_PATH % file)
		_cache[file] = stream
	return stream.get_length() if stream != null else 0.0


## ---- headless, taping: what would have played, with no sound made
## Headless has no Audio, so `taping` runs the picks and tapes what would have played.
## Why: docs/why/Audio.md#taping
var _dry: Array = []                ## [asked, end game s]
## asked -> the most voices of it ever in the air at once
var dry_peak: Dictionary = {}


func _dry_play(pick: StringName, asked: StringName, db: float, pitch: float, from: float) -> void:
	var now := GameClock.now()
	var stream: AudioStream = _cache.get(pick)
	if stream == null and ResourceLoader.exists(SFX_PATH % pick):
		stream = load(SFX_PATH % pick)
		_cache[pick] = stream
	var length := (stream.get_length() - from) / maxf(pitch, 0.01) if stream != null else 0.3
	_dry = _dry.filter(func(v: Array) -> bool: return float(v[1]) > now)
	_dry.append([asked, now + length])
	var n := 0
	for v: Array in _dry:
		if v[0] == asked:
			n += 1
	dry_peak[asked] = maxi(int(dry_peak.get(asked, 0)), n)
	tape.append([pick, Time.get_ticks_msec(), db, pitch, now, Engine.get_process_frames(), asked, from])


func _dry_steal(asked: StringName, cap: int) -> void:
	var now := GameClock.now()
	_dry = _dry.filter(func(v: Array) -> bool: return float(v[1]) > now)
	var live: Array = _dry.filter(func(v: Array) -> bool: return v[0] == asked)
	while live.size() >= maxi(cap, 1):
		_dry.erase(live.pop_front())

# ---------------- signal handlers ----------------

## The thermal ruling made audible: heat-printing cards get the zap, others the dry crack.
func _on_card_played(c: CardData) -> void:
	play(&"card_play", 0.05)
	if c.damage > 0 or c.damage_equals_heat or c.heat_scale > 0:
		# What the card mechanically IS picks the family; the files carry
		# round robins so no two shots are the exact same take.
		if c.charge_turns > 0:
			play(&"charge_up", 0.04)           # it starts charging; it fires later
		elif c.hits >= 2:
			play(&"shot_auto", 0.06)           # autocannon burst
		elif c.heat > 0 or c.damage_equals_heat or c.heat_scale > 0:
			play(&"shot_energy", 0.06)         # hot discharge
		else:
			play(&"shot_kinetic", 0.06)        # one cold slug
	elif c.vent > 0 or c.vent_all:
		play(&"vent", 0.05)
	elif c.block > 0:
		play(&"shield_block", 0.06)
	# Brace is plating: the picture plays its sound when the plates go on; here only if set back.
	elif c.brace > 0 or c.brace_from_heat:
		fx(&"brace_on_yours", &"card")
	# Emergency repair keeps the berth's old welding sound, at Jon's ask.
	elif c.heal > 0 or c.heal_scale > 0:
		play(&"svc_repair", 0.06)
	# Lock on gets the reticle sound after the family above, not instead of it.
	if c.lock_on > 0:
		play(&"lock_on", 0.05, 120)

## The heat warning fires on the way up only: a tone on every move while hot would mean nothing.
func _on_combat_state() -> void:
	var cap := Run.heat_cap()
	var hot: bool = cap > 0 and float(Run.heat) >= float(cap) * HEAT_WARN_AT
	if hot and not _hot:
		play(&"heat_warn", 0.02)
	_hot = hot

## Watching the two totals makes the sound right by construction, with no call in six files.
## Why: docs/why/Audio.md#resource-polling
func _poll_resources() -> void:
	var credits := Run.credits
	var cargo := Run.cargo.size()
	if _last_credits >= 0 and credits > _last_credits:
		play(&"scrap_gain", 0.08, 110)
	if _last_cargo >= 0 and cargo > _last_cargo:
		play(&"loot_drop", 0.03, 200)
	_last_credits = credits
	_last_cargo = cargo

## What died decides the sound: bosses a two-stage death, fauna none. `limit_ms` stops a roll.
## Why: docs/why/Audio.md#kill-sounds
func kill_beat(s: float) -> void:
	if s >= 0.6:
		fx(&"kill_boom", &"broke")
		fx(&"kill_thump", &"broke")
		fx(&"kill_crunch", &"broke")
	else:
		fx(&"kill_pop", &"broke")


func play_kill(who: int, db: float = 0.0) -> void:
	var t: EnemyTemplate = null
	if Router.combat != null and who >= 0 and who < Router.combat.enemies.size():
		t = Router.combat.enemies[who].template
	if t != null and t.fauna:
		# on the death's first beat (`SectorScreen._on_death_moment`), at the
		# row's own level
		fx(&"fauna_death")
	else:
		# One pool for every kill, at Jon's ask, so a boss is not louder than what it dies beside.
		play(&"explosion_small", 0.09, 160, db)

func _on_hit_landed(amount: int, to_player: bool, _who: int, absorbed: int) -> void:
	if amount <= 0:
		# Taken whole by block or brace: the plate ringing, not the hull.
		if absorbed > 0:
			play(&"shield_block", 0.06, 90, -4.0)
		return
	# PARTLY TAKEN: the plate (or the bubble) rang too, under the impact
	if absorbed > 0:
		fx(&"hit_partial")
	if to_player:
		play(&"impact_hull", 0.05)
	else:
		# Your shot landing on THEM: distance runs cold, so it is small and
		# dry. limit_ms keeps multi-hit turns from machine-gunning it.
		play(&"impact_enemy", 0.08, 90)

func _on_combat_ended(result: StringName, _summary: String) -> void:
	# No sting for winning: Jon cut it; a fanfare over the reward was the game applauding itself.
	match result:
		&"fled": play(&"ui_tab", 0.03)
		_: pass          ## death is handled by run_ended, so it is not doubled

## No sting win or lose: a death sting talked over the No Fault cue, written to be the ending.
## Why: docs/why/Audio.md#run-end-silence
func _on_run_ended(_won: bool, _reason: String) -> void:
	pass


# ---------------- volume ----------------

func set_volume(bus: StringName, value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	match bus:
		&"Master": master_volume = value
		&"Music": music_volume = value
		&"SFX": sfx_volume = value
		&"Ambient": ambient_volume = value
	_apply_volumes()
	save_settings()

func volume_of(bus: StringName) -> float:
	match bus:
		&"Music": return music_volume
		&"SFX": return sfx_volume
		&"Ambient": return ambient_volume
		_: return master_volume

func _apply_volumes() -> void:
	for pair in [[&"Master", master_volume], [&"Music", music_volume], [&"SFX", sfx_volume],
			[&"Ambient", ambient_volume]]:
		var idx := AudioServer.get_bus_index(pair[0])
		if idx < 0:
			continue
		var v: float = pair[1]
		# Faders are linear because that is what a slider position means to a
		# player; the bus wants dB. Zero is a mute, not -inf dB.
		AudioServer.set_bus_mute(idx, v <= 0.001)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))

## Shares user://settings.cfg with DisplaySettings, in its own section (the
## harness's scratch file under a harness: `DisplaySettings.path`).
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(DisplaySettings.path)            ## keep the display section
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "ambient", ambient_volume)
	cfg.save(DisplaySettings.path)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(DisplaySettings.path) == OK:
		master_volume = float(cfg.get_value("audio", "master", master_volume))
		music_volume = float(cfg.get_value("audio", "music", music_volume))
		sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
		ambient_volume = float(cfg.get_value("audio", "ambient", ambient_volume))
		# auditioning the effects' takes: `[fx] brace_on="before"` (the command
		# line's `fx=` wins, read after)
		if cfg.has_section("fx"):
			for row: String in cfg.get_section_keys("fx"):
				if not fx_choice.has(StringName(row)):
					fx_choose(StringName(row), str(cfg.get_value("fx", row)))
	_apply_volumes()


# ---------------------------------------------------------------- the map's ship
# The map ship plays LOCAL's drive sound, quieter, as a small thing you hear a lot.
const SHIP_DB := -8.0
## Folded and PCM with a low-pass: a tick 0.65 s in clicked once a loop (Jon).
## Why: docs/why/Audio.md#thrust-loop
const SHIP_LOOP := &"ship_thrust_loop"
var _ship_loop: AudioStreamPlayer = null
var _ship_level := 0.0
## The level the burn was last asked for (0 once it is off).
var ship_want := 0.0
var _ship_depart: AudioStreamPlayer = null
var _ship_arrive: AudioStreamPlayer = null


## The loop's level, every frame the map runs: 0.7 thrusting, 0.45 braking, 0.32
## turning or nudging an orbit, 0 for nothing. Fades in fast and out slower.
func ship_thrust(level: float) -> void:
	# (the level is kept headless too, where nothing sounds, so a test reads
	# what was asked for and what would be heard: `ship_want`, `_ship_level`)
	ship_want = level
	var dt := get_process_delta_time()
	var tc := 0.03 if level > _ship_level else 0.08
	_ship_level += (level - _ship_level) * (1.0 - exp(-dt / tc))
	if not _enabled:
		return
	if _ship_loop == null:
		# STARTED SILENT, the first time the map asks, and never restarted: a
		# play() on a key press started the burn mid-swing, from silence -- a click
		if not ResourceLoader.exists(SFX_PATH % SHIP_LOOP):
			return
		_ship_loop = AudioStreamPlayer.new()
		_ship_loop.bus = &"SFX"
		_ship_loop.stream = load(SFX_PATH % SHIP_LOOP)
		_ship_loop.volume_db = -80.0
		add_child(_ship_loop)
		_ship_loop.play()
	_ship_loop.volume_db = -80.0 if _ship_level < 0.002 else SHIP_DB + linear_to_db(_ship_level)


## THE MAP LEFT: the burn faded out in a tenth of a second (a frame of
## `ship_thrust(0)` only eases it, and no frame follows).
func ship_thrust_off() -> void:
	ship_want = 0.0
	_ship_level = 0.0
	if _ship_loop != null and _ship_loop.volume_db > -79.0:
		create_tween().tween_property(_ship_loop, "volume_db", -80.0, 0.1)


# ---------------------------------------------------------------- the idle
# A bed read each frame off the view (`ShipView.idle_heard`), so it cannot miss an edge.
# Why: docs/why/Audio.md#idle-engines
const IDLE_LOOP := &"ship_idle"
## Level measured: -44 LUFS as heard, 4 dB down from -17 at Jon's pick.
## Why: docs/why/Audio.md#idle-engines
const IDLE_DB := -21.0
## In and out over the same 0.3 s: long enough that the bed never steps, short
## enough that it is gone with the flame.
const IDLE_FADE_S := 0.3
var _idle_src: WeakRef = null
var _idle_player: AudioStreamPlayer = null
## What the picture says this frame, and the fade toward it (0..1). Kept on a
## headless run too, where no sound exists, so a test can read the decision.
var idle_want := false
var idle_level := 0.0


## Own node, last in the frame, so the bed reads the frame being drawn, not the one before.
class IdleClock extends Node:
	var audio: Node
	func _init() -> void:
		process_priority = 1000
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _process(delta: float) -> void:
		audio.call(&"_tick_idle", delta)
var _idle_clock: Node = null


## The view whose idle flame is heard. One at a time; the newest wins.
func idle_from(view: Node) -> void:
	_idle_src = weakref(view) if view != null else null


func _tick_idle(delta: float) -> void:
	var v: Node = _idle_src.get_ref() as Node if _idle_src != null else null
	idle_want = v != null and is_instance_valid(v) and v.has_method(&"idle_heard") \
			and bool(v.call(&"idle_heard"))
	idle_level = move_toward(idle_level, 1.0 if idle_want else 0.0, delta / IDLE_FADE_S)
	if not _enabled:
		return
	if _idle_player == null:
		if idle_level <= 0.0 or not ResourceLoader.exists(SFX_PATH % IDLE_LOOP):
			return
		_idle_player = AudioStreamPlayer.new()
		_idle_player.bus = &"SFX"
		# Held with the game: the bed is part of the picture, so a paused tree pauses it.
		_idle_player.process_mode = Node.PROCESS_MODE_PAUSABLE
		_idle_player.volume_db = -80.0
		_idle_player.stream = load(SFX_PATH % IDLE_LOOP)
		add_child(_idle_player)
		# STARTED SILENT AND NEVER RESTARTED, like the map's thrust loop: the
		# fade alone brings it in and out, so no play() lands mid-swing
		_idle_player.play()
	var g := idle_level * _duck
	_idle_player.volume_db = -80.0 if g < 0.002 else IDLE_DB + linear_to_db(g)


func _ship_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"SFX"
	add_child(p)
	return p


## Arrival flameout starts where its clean burn ends 0.08 s before settling, over the stutter.
## Why: docs/why/Audio.md#flight-sound
func ship_flight(dur: float, conic: bool) -> void:
	if not _enabled:
		return
	var w := int(Run.hull.weight) if Run.hull != null else int(HullData.Weight.MEDIUM)
	var row := randi() % ShipView.FLAMEOUTS.size()
	var dname: StringName = ShipView.DEPART_SFX[w]
	var aname: StringName = (ShipView.FLAMEOUT_SFX[w] as Array)[row]
	if _ship_depart == null:
		_ship_depart = _ship_player()
		_ship_arrive = _ship_player()
	# the departure burn, then out
	if ResourceLoader.exists(SFX_PATH % dname):
		_ship_depart.stream = load(SFX_PATH % dname)
		_ship_depart.volume_db = SHIP_DB
		_ship_depart.play()
		var tw := create_tween()
		tw.tween_interval((0.18 if conic else 0.45) * dur)
		tw.tween_property(_ship_depart, "volume_db", -80.0, (0.2 if conic else 0.3) * dur)
	# the flameout, where its clean burn ends as the ship settles
	if ResourceLoader.exists(SFX_PATH % aname):
		var flame: float = ShipView.ARRIVE_LEAD_S + (ShipView.FLAMEOUTS[row][0] as Vector2).y * ShipView.ARRIVE_MS / 1000.0
		var at := dur - 0.08 - flame
		var from := 0.0
		if at < 0.0:
			from = -at
			at = 0.0
		_ship_arrive.stream = load(SFX_PATH % aname)
		_ship_arrive.volume_db = -80.0
		var up := (0.76 if conic else 0.3) * dur
		var full := (0.84 if conic else 0.6) * dur
		var tw2 := create_tween()
		if at > 0.0:
			tw2.tween_interval(at)
		tw2.tween_callback(func() -> void: _ship_arrive.play(from))
		tw2.tween_interval(maxf(0.0, up - at))
		tw2.tween_property(_ship_arrive, "volume_db", SHIP_DB, maxf(0.05, full - maxf(up, at)))
