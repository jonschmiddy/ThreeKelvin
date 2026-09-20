extends Node
## Music and sound.
##
## Music is vertical, not horizontal. A cue is not one file: it is six stems
## that all start on the same sample, and `intensity` decides how many of them
## you can hear. Nothing restarts when a fight begins -- the arrangement opens
## up. That is why the transition costs nothing and cannot land you in the
## wrong place.
##
## THE SECOND EDITION, 2026-09-12. The first soundtrack was thirteen cues built
## from one whistled five-note phrase, tempo-locked at 142 BPM, each cue doing
## one thing to the motif. Jon played the finished game and called it hollow,
## sickly, a slow funeral, not musical at all. The fault was the FORM rather
## than the details: a four-bar loop with a tune over it is a song, and this
## game wanted a score.
##
## So there is no tempo now, and no bar lines. Every cue is a low F pedal that
## never moves, harmony that changes about once a minute above it, texture that
## opens over twenty seconds, and one five-note theme that arrives three times a
## loop as an event rather than a layer. Cues differ by how dark they are, which
## harmonic areas they use, and whether the theme states its aching form or its
## answer. Crossfading between two of them still works because they share the
## pedal -- the same trick the old set used, for the same reason.
##
## The rulings that shape it, and the mistakes that produced them, are in
## `audio/space.py`. The old composition notes in `docs/audio/` describe the
## first edition and are kept as its record.

const SFX_PATH := "res://assets/audio/sfx/%s.wav"
const ROOM_PATH := "res://assets/audio/ambience/%s.ogg"

const OFF_DB := -60.0      ## silent, but still a running player
const SFX_VOICES := 14
## Fraction of heat capacity that counts as "running hot".
const HEAT_WARN_AT := 0.8

var master_volume: float = 0.9
var music_volume: float = 0.7
var sfx_volume: float = 0.9

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
## One per voice, or null. A hush fades a voice out over a moment rather than
## stopping it dead, so the fade has to be KILLABLE: the round robin will come
## back to that voice long before a run is over, and a tween still dragging its
## volume down would take the next sound with it. See `hush` and `play`.
var _fade: Array[Tween] = []
var _cache: Dictionary = {}
var _variants: Dictionary = {}  ## name -> [name, name_2, ...] round robins
## FOR THE HARNESSES. While `taping` is on, every effect that actually plays --
## after rate limits and suppression have had their say, so nothing that was
## dropped -- is appended as [name, msec, db, pitch]. A film can then lay the
## sounds the game really made under its frames, rather than the ones the
## harness expected it to make. Off in play; nothing reads it but a harness.
var taping: bool = false
var tape: Array = []
var _last: Dictionary = {}          ## sfx name -> msec, for rate limiting
var _enabled: bool = true
var _last_credits: int = -1
var _last_cargo: int = -1
var _hot: bool = false

## ---------------- room tone ----------------
## ONE PLAYER, ONE ROOM AT A TIME. Nothing in this game is in two places at
## once, so a second room playing under the first is a bug rather than a mix.
var _room: AudioStreamPlayer = null
var _room_now: StringName = &""
var _room_fade: Tween = null
## MEASURED, NOT CHOSEN. The file is levelled to peak −1.0 dB so the ogg keeps
## its resolution, and this puts back what that normalise took off.
##
## −14.0 SINCE THE BENCH, and it was −3. Jon mixed the station on a page that
## plays at the game's own gain, and the faders came down 6 to 16 dB: a
## quieter station, asked for by ear. The build lifts the file back to the
## ceiling, so the drop has to be restored here or it is silently undone. The
## bench's master is −18.7 dB (the old build gain −15.7, plus −3); the new
## build's gain is −4.75, so the player makes up the rest: −18.7 + 4.75.
## RE-DERIVE THIS after any change to station.py's MIXDB -- it moves the gain.
const ROOM_DB := -14.0
## EACH ROOM AT ITS OWN LEVEL. The station is a place you stand in with the
## music gone; open space plays UNDER the score, so it sits well below it --
## about 10 dB under a cue's average once both are through the Music bus.
## −27 is that arithmetic (file −13.1 dB RMS, target −40), not an audition:
## Jon has not heard it in the game yet.
##
## THE STAR ROOMS land at the same loudness as open space (-40 dBFS RMS once
## played), each from its own file's measured RMS -- star_rooms.py prints the
## number. They are open space with a particular star outside: under the score.
## No entry for open space any more: ordinary systems have no room at all.
const ROOM_LEVELS: Dictionary = {&"amb_station": ROOM_DB,
		&"amb_blue": -19.3, &"amb_red": -24.8, &"amb_pulsar": -22.5}
const ROOM_FADE := 1.6     ## seconds, because a room does not arrive on a beat

## THE SCORE STEPS ASIDE WHILE SOMEBODY IS TALKING. The announcements are baked
## into the bed, so raising them only fights the crowd — against the soundtrack
## they still lost, which is what "it fades behind the music" means. A PA does
## not win that argument by being louder, it wins by being the thing a room
## goes quiet for.
##
## The bed loops on a known length and the lines sit at known offsets, so the
## playhead says exactly when one is running. No analysis, no envelope
## follower, no sidechain — a lookup against a list of six pairs.
const DUCK_DB := -9.0      ## how far the music drops under an announcement
const DUCK_IN := 0.35      ## seconds down: quick, or the first words are lost
const DUCK_OUT := 1.20     ## and slow back up, so it is not a pumping effect
var _speech: Array = []    ## [[start, end], ...] seconds into the room loop
var _room_loop: float = 0.0
var _duck: float = 1.0     ## 1 is unducked; multiplies every music stem

## AND THE SCORE SITS BACK WHENEVER THERE IS A ROOM AT ALL. A docked station is
## the one place in this game with other people in it, and it now has a crowd,
## six announcements and ships arriving of its own. The soundtrack at full over
## that is two pieces of music competing; at half it is a score playing
## somewhere in the building, which is what it is.
##
## SEPARATE FROM THE ANNOUNCEMENT DUCK, and they multiply. Being docked is a
## PLACE and a line being read is a MOMENT -- folding them into one number would
## mean picking between "quieter in stations" and "quieter while somebody
## talks", and both are wanted.
##
## "LIKE 50%" WAS ASKED FOR WHEN THE MUSIC WAS 14 dB LOUDER, and half of that
## turned out to be too far: docked came back "a bit too quiet". Both cuts were
## landing on top of each other -- -6 here on a baseline that had just dropped
## -14 -- so this is the one that gave, since MUSIC_DB is right everywhere else
## and this is right in exactly one place. -3 dB instead of -6: the score still
## steps back for the room, by half as much.
##
## AND THEN ALL THE WAY. Jon mixed the station on the bench with the music at
## −40 and no duck, and asked: "What about no music in the stations?" So a
## docked station is its own room and nothing else. The cue does NOT stop: it
## keeps its place, silent, and comes back up over the same 1.6 s on leaving,
## so undocking resumes the run's music mid-phrase rather than restarting it.
## The announcement duck above still runs and now has nothing to act on --
## left in place, because a room tone somewhere else may want music under it.
const ROOM_DUCK := 0.0     ## silent, while docked
## WHICH ROOMS PUSH THE SCORE ASIDE. Only the station: open space is the
## sound UNDER the music, not instead of it, and a room missing from here
## leaves the music alone.
const ROOM_DUCKS: Dictionary = {&"amb_station": ROOM_DUCK}
const ROOM_DUCK_S := 1.6   ## and it arrives with the room, not before it
var _rduck: float = 1.0

# ---------------- the bed ----------------
## THERE IS NO ROOM TONE ANY MORE, and this note is the whole record of why.
##
## Three procedural loops used to run under everything — a reactor pedal riding
## heat, a hull that ticked and creaked, a distant radio near settled space.
## They are gone: Jon is sourcing ambience from ElevenLabs instead, which is a
## better tool for the job than a numpy script with opinions. `audio/ambience.py`
## and `assets/audio/ambience/` went with them; git has them if they are wanted.
##
## WHEN THEY COME BACK, they do not come back as cues. A cue is a composition
## with a bar line, a rung ladder and a crossfade that has to land on a beat.
## Room tone is continuous, seamless on its own length, and its level answers to
## the ship and the place rather than to a screen — so it wants its own player
## on the Music bus (scenery, not feedback: turning effects down should not take
## the room with it) and a fade measured in seconds, not in beats.

## AND THEY HAVE COME BACK, ON EXACTLY THOSE TERMS. `amb_station` is the first:
## one ogg, ninety seconds, seamless on its own length, on its own player on
## the Music bus with a fade in seconds. It is NOT in the cue system and must
## not be — `room()` is four lines because room tone genuinely is four lines
## once you stop trying to make it a cue.
##
## IT IS NOT SYNTHESISED EITHER. The three loops that used to live here were a
## numpy script with opinions, and the replacement is assembled: bought crowd
## and bought berthings under bought announcements, over a hum and a deck that
## oscillators are genuinely good at. `audio/station.py` in the scratchpad
## builds it and prints its own seam and level checks on every run.

func _ready() -> void:
	# The balance sim boots the whole project so the autoloads exist. It runs
	# hundreds of combats with no window and no audio device, and loading 36 MB
	# of streams for it would be pure cost. Same guard Main.gd uses.
	if "sim" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		_enabled = false
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
	Sig.damage_dealt.connect(_on_damage)
	# THE RELEASE of a charged card is a heavy shot, because that is what it is.
	# It used to play `charge_fire` here and the heavy shot on PLAY -- a gunshot
	# at the one moment nothing fires. Jon: "there should be a charging sound
	# and a release sound. separate." The charging half is in _on_card_played.
	Sig.charge_fired.connect(func(_n: String) -> void: play(&"shot_heavy", 0.05))
	Sig.overheated.connect(func(_b: int) -> void: play(&"overheat"))
	# NO STING WHEN A FIGHT STARTS. The music already tells you: combat moves the
	# cue to Hard Burn, which is 160 BPM of sixteenths against everything else in
	# the soundtrack. A sting on top of that is the score saying the same thing
	# twice, half a second apart, and the second one is louder.
	Sig.combat_ended.connect(_on_combat_ended)
	# NO SOUND ON Sig.jumped. It played `jump`, the convoy's bang, and the
	# player's own departure had to suppress it under the drive and the flare
	# -- which play their own. Jon cut `jump` in the sound pass: "Just use the
	# jump out sound." The convoy plays `hyperjump` itself (EncounterView).
	Sig.enemy_destroyed.connect(_on_enemy_destroyed)
	# Paperwork: the ledger stamps with the institutions' bare fifth, same
	# figure the score's stamp lanes carry.
	Sig.contracts_changed.connect(func() -> void:
		play(&"contract_stamp", 0.04, 250))
	Sig.archive_changed.connect(func() -> void:
		play(&"archive_found", 0.05, 400))
	# Every screen change is the same pressure door -- _swap() is the one
	# chokepoint, so the sound is right by construction, like the resource
	# poll. limit_ms soaks the double-swap paths (flee already stings, and
	# some routes swap twice on the way somewhere) -- 60 ms, not the 350 it
	# was: a double swap lands within a frame or two, and 350 swallowed real
	# clicks when you tabbed quickly ("sometimes doesn't happen").
	Sig.screen_changed.connect(func() -> void:
		play(&"ui_tab", 0.04, 60))
	# ship_changed used to play module_install for EVERYTHING -- a sale
	# sounded like an installation. The desk actions now carry their own
	# sounds at the UI call sites (StationScreen/SectorScreen _on_action),
	# which also keeps bot pilots from clicking speakers they do not have.
	Sig.run_ended.connect(_on_run_ended)
	# Draw on turn start, not on hand_changed — the hand also changes when a
	# card leaves it, which put a draw sound on top of every card played.
	Sig.turn_started.connect(func(_t: int) -> void: play(&"card_draw", 0.10, 70))
	Sig.player_combat_state_changed.connect(_on_combat_state)
	Sig.resources_changed.connect(_poll_resources)
	Sig.screen_changed.connect(_poll_resources)
	Sig.run_started.connect(func() -> void:
		_last_credits = -1
		_last_cargo = -1
		_hot = false)

# ---------------- music ----------------
##
## ONE FILE PER CUE, NOT A STACK OF STEMS. The edition before this built
## intensity by adding rungs to a piece already playing; finished cues
## arrived instead, each arranged end to end, so intensity is now a different
## PIECE rather than more of the same one. Everything a rung ladder needed --
## CUES, STATES, DEEP, TRACKS, the stem mixer -- went with it. git has it.
##
## The cues live in `music/`, where one browser page is the source of every
## note. Read `music/CLAUDE.md` before changing any of them, and run
## `music/tools/check_cue.mjs` and `check_lab.mjs` after; validate.sh does both.

## WHICH CUE, BY TIER AND BY WHETHER YOU ARE FIGHTING. Straight out of
## `docs/audio/music/tiers.md`, which is the handoff's own table.
##
## FOUR RUN CUES A TIER NOW, up from two or three. The second handoff added ten
## cues and they all land here; the fight cues did not change. With four, "not
## the same one twice running" stops being strict alternation and becomes a real
## shuffle with the one repeat that matters ruled out.
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
## THE ONE CUE THAT DOES NOT LOOP. Lights Out is fifty seconds of music and then
## twenty of written silence, and `tiers.md` is plain about it: play it once from
## zero and let it run out. Looped, a death would restart its own elegy every
## seventy seconds for as long as the game-over screen sat there.
const DEATH_CUE := &"lightsout"
const ONE_SHOT: Array[StringName] = [DEATH_CUE]

## HOW DEEP YOU ARE, IN FIVE STEPS. `MapGen.LAYERS` is 15 and there are five
## tiers, so three layers each and no remainder. Layer is the right signal
## because a tier describes a JOURNEY: it only goes one way, and the score
## should not walk back to the opening because one system happened to be quiet.
const TIERS: Array[StringName] = [&"EASY", &"ROUGH", &"HARD", &"BRUTAL", &"LETHAL"]
const TIER_SPAN := 3

## A BAD SYSTEM PLAYS ONE TIER UP, which is the old DREAD_DANGER ruling kept
## rather than a second threshold invented. Past this point the soundtrack
## admits where you are, and a shallow bloodbath stops sounding like the rim.
const DREAD_DANGER := 8

## Seconds of musical loop per cue, from the sidecar the renderer writes. NOT
## the file length: every cue carries six seconds of reverb tail past its last
## bar, and that tail is the whole reason the loop works -- see `_relay`.
const LOOPS_PATH := "res://assets/audio/music/loops.json"
const MUSIC_PATH := "res://assets/audio/music/%s.ogg"
const TAIL := 6.0          ## seconds of tail after the loop point, by construction
const SWAP := 2.5          ## crossfade between two different cues

## HOW LOUD A CUE PLAYS, and it is not "as rendered". Every cue is normalised to
## about -1 dBFS peak, and this played them at full gain -- Jon: "the music in
## general is about 5X louder than I would ever want it." Five times in
## amplitude is 20*log10(5), so:
const MUSIC_DB := -14.0
##
## The handoff said as much and I did not do it: `docs/audio/music/godot.md`
## says "start the Music bus around -6 dB and tune from there", and nothing was
## trimmed anywhere. -14 is what the tuning actually came to, which is why it
## lives here as a measured number rather than as the doc's starting guess.
##
## HERE AND NOT ON THE BUS, so `music_volume` stays what the player set and this
## stays what the mix wants. A slider that has to sit at 0.2 to sound right is a
## slider with four fifths of its travel wasted.

func music_state(state: StringName) -> void:
	if not _enabled:
		return
	# A PANEL ASKS FOR NOTHING, and that ruling outlived the system it was written
	# for. Jon: "I don't really want the music to change when I change panels. At
	# all." The new set has no cue for a station, a chart, a hold or the archive
	# either, so the rule now covers all of them: whatever the place put on keeps
	# playing, and only leaving the run changes it.
	match state:
		&"menu", &"lobby":
			play_cue(TITLE_CUE)
		&"gameover":
			# Lights Out, once, and then silence. This was a fade to nothing until
			# the lab wrote a death cue; the silence is still there, just written
			# into the last twenty seconds of the file instead of left to chance.
			play_cue(DEATH_CUE)
		&"boss":
			play_cue(BOSS_CUE)
		&"combat":
			play_cue(FIGHT_CUES[_tier()])
		_:
			_run_music()

## The tier's run music, picked once and then left alone. Called for every place
## that is not a fight, so walking from the sector to the station to the chart
## and back does not touch the music at all.
func _run_music() -> void:
	var tier := _tier()
	var cues: Array = RUN_CUES[tier]
	if _cue in cues:
		return                                  ## already somewhere in this tier
	play_cue(_pick(tier, cues))

## NOT THE SAME ONE TWICE RUNNING. With two cues in most tiers that is strict
## alternation, which is the point: hearing the same piece twice in a row is
## what makes a small set feel smaller than it is.
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
	# NOT LOOPED BY THE STREAM. Godot's ogg import can say where to jump back TO
	# and not where to loop FROM, and every one of these files carries six seconds
	# of tail past its last bar -- so stream looping would play that tail before
	# every downbeat. `_relay` does the looping instead, and uses the tail.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	_cue = cue
	_swap_to(stream, SWAP)

## The room you are standing in. `&""` is outside, and outside is silent.
##
## FADED, NEVER CUT. A room that stops dead is the loudest possible way to say
## "that was a file". Both directions run through the same tween, which is
## killed first — tabbing between the station and the ship screen fast enough
## would otherwise leave two fades fighting over one volume.
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
		_speech = []
		return
	var stream: AudioStream = load(ROOM_PATH % name)
	if stream == null:
		push_warning("Audio: missing room tone %s" % name)
		_room_now = &""
		return
	# Seamless on its own length, so tell the stream that rather than letting it
	# stop at ninety seconds and leave the station silent for the rest of a dock.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_load_speech(name)
	if _room == null:
		_room = AudioStreamPlayer.new()
		_room.bus = &"Music"
		add_child(_room)
	_room.stream = stream
	_room.volume_db = OFF_DB
	_room.play()
	_room_fade = create_tween()
	_room_fade.tween_property(_room, ^"volume_db",
			float(ROOM_LEVELS.get(name, ROOM_DB)), fade_s)


## WHEN THE ROOM IS TALKING, IF IT IS. A room with no sidecar simply never
## ducks, which is the right answer for one that has nobody in it.
func _load_speech(name: StringName) -> void:
	_speech = []
	_room_loop = 0.0
	var path := "res://assets/audio/ambience/%s.json" % name
	if not FileAccess.file_exists(path):
		return
	var txt := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Audio: %s is not readable" % path)
		return
	_room_loop = float((data as Dictionary).get("loop", 0.0))
	_speech = (data as Dictionary).get("speech", [])


## Is the bed mid-sentence right now?
##
func _room_talking() -> bool:
	if _room == null or not _room.playing:
		return false
	return _talking_at(_room.get_playback_position())


## Split out from `_room_talking` ONLY so it can be tested. The playhead is the
## one input here and it cannot be set from a harness, so the decision lives in
## a function that takes a time and the reading lives in the caller.
func _talking_at(t: float) -> bool:
	if _speech.is_empty() or _room_loop <= 0.0:
		return false
	# MODULO THE LOOP, because `get_playback_position` keeps counting past the
	# end on a looping stream — second time round it reads 361 seconds and every
	# window is behind it forever, so the music would never duck again.
	var at: float = fmod(t, _room_loop)
	for w: Variant in _speech:
		var pair := w as Array
		if pair.size() == 2 and at >= float(pair[0]) and at <= float(pair[1]):
			return true
	return false


func stop_music() -> void:
	if not _enabled:
		return
	_cue = &""
	for i in _mv.size():
		_ramp(i, 0.0, SWAP)

## ---------------- the two voices ----------------
##
## TWO PLAYERS AND NOTHING ELSE. One carries the cue, the other is free; a cue
## change crossfades between them, and so does the loop. A third would only be
## wanted if a loop could land inside a cue change, which SWAP and TAIL are
## sized to prevent.

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

## THE LOOP, AND THE TAIL IS WHY IT SOUNDS RIGHT. At the last bar the next pass
## starts on the other voice at full, and this one is left running -- what comes
## out of it from here is the reverb of the bar that just ended, ringing over
## the new downbeat. That is what the six seconds were printed for, and it is
## the seam `docs/audio/music/godot.md` says is audible on the wet cues.
func _relay() -> void:
	var p: AudioStreamPlayer = _mv[_now]
	var nxt := 0 if _now != 0 else 1
	var o: AudioStreamPlayer = _mv[nxt]
	o.stream = p.stream
	# The fallback is the cue level, not 1.0 -- full scale is no longer unity.
	o.set_meta(&"g", float(p.get_meta(&"g", db_to_linear(MUSIC_DB))))
	o.play()
	_now = nxt
	# The outgoing voice keeps its level and simply runs out of file.
	var t := create_tween()
	t.tween_interval(TAIL)
	t.tween_callback(p.stop)

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

## What is playing. A name rather than a list, because there is only ever one.
func cue() -> StringName:
	return _cue

func _process(delta: float) -> void:
	if not _enabled:
		return
	# ASKED EVERY FRAME, NOT FIRED ON AN EVENT. Whether a line is playing is a
	# fact about the playhead, so reading it each frame is both simpler than
	# scheduling six timers against a loop and immune to a missed edge: tab away
	# mid-sentence and come back and the duck is simply correct, where a timer
	# would be stuck down until the next announcement let it up.
	var duck_to: float = db_to_linear(DUCK_DB) if _room_talking() else 1.0
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

## ONE VOICE PER HOLD/HULL ACTION, wherever a screen triggers it. Three screens
## hand-picked these name-and-pitch pairs independently and `module_install`
## had already drifted to two different variances between them -- each site read
## as locally correct, so nothing caught it. The pair is data; it lives once.
const ACT_SFX: Dictionary = {
	&"module_install": 0.04,
	&"module_uninstall": 0.05,
	&"module_scrap": 0.05,
	&"hull_transfer": 0.03,
}

func act(name: StringName) -> void:
	play(name, float(ACT_SFX.get(name, 0.06)))


## pitch_var randomises playback rate a little, which is what keeps a click
## you hear four hundred times an hour from turning into a machine gun.
## limit_ms drops repeats inside a window, for signals that fire in bursts.
## `db` is an OFFSET, and it is new. Every cue played at whatever level it was
## mastered at, which is right for a game where each sound happens once at a
## moment that earned it -- and wrong the moment one of them starts happening
## six times a system. `loot_drop` is written as a reward sting; taking a crate
## off the floor does not deserve one, but the alternative was authoring a second
## quieter file rather than turning the existing one down.
func play(name: StringName, pitch_var: float = 0.06, limit_ms: int = 0,
		db: float = 0.0) -> void:
	if not _enabled:
		return
	var now := Time.get_ticks_msec()
	# SUPPRESSION IS NOT A RATE LIMIT, and it was only ever read as one. `suppress`
	# writes a moment in the future into `_last`, and that was checked solely when
	# the caller passed a limit -- so `Sig.jumped`, which plays `jump` with none,
	# went straight through, and the convoy crack played on every jump it had been
	# silenced for. The sound tape in `jumpcine whole` is what caught it.
	if int(_last.get(name, 0)) > now:
		return
	if limit_ms > 0 and now - int(_last.get(name, -limit_ms)) < limit_ms:
		return
	_last[name] = now
	# Round robins: a name with `name_2.wav`, `name_3.wav`... beside it
	# plays a random take.  One file per shot always reads as a toy, no
	# matter how good the file is -- the ear catches the exact repeat.
	var pick := name
	var vars: Array = _variants.get(name, [])
	if vars.is_empty() and not _variants.has(name):
		vars = [name]
		# UP TO _16, it was _4 then _8. Merging the kill pools made
		# explosion_small five takes, then the autocannon kept nine, and a
		# scan that stops short drops the rest without a word. Numbers only:
		# thrusters use letters.
		for i in range(2, 17):
			var vn := StringName("%s_%d" % [name, i])
			if ResourceLoader.exists(SFX_PATH % vn):
				vars.append(vn)
		_variants[name] = vars
	if vars.size() > 1:
		pick = vars[randi() % vars.size()]
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
	# WHATEVER THIS VOICE WAS DOING, IT IS NOT DOING IT NOW. A hush left a tween
	# pulling this player's volume toward silence; reusing it without killing
	# that would start the new sound and fade it out underneath itself.
	if _fade[_sfx_next] != null and _fade[_sfx_next].is_valid():
		_fade[_sfx_next].kill()
	_fade[_sfx_next] = null
	_sfx_next = (_sfx_next + 1) % _sfx.size()
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.volume_db = db
	# WHAT THIS VOICE IS CARRYING, so `hush` can find it again. The pick, not the
	# name asked for -- a round robin plays `thruster_arrive_c` when the caller
	# said `thruster_arrive`, and a hush naming either has to land.
	p.set_meta(&"cue", pick)
	p.set_meta(&"asked", name)
	if taping:
		tape.append([pick, Time.get_ticks_msec(), db, p.pitch_scale])
	p.play()

## Hold a name's tongue for a moment. The resource watcher plays loot_drop
## and scrap_gain on ANY cargo/credit increase -- right for a windfall,
## wrong layered over a screen that just played its own, better-informed
## sound for the same change. The screen calls this before it speaks.
func suppress(name: StringName, ms: int = 400) -> void:
	_last[name] = Time.get_ticks_msec() + ms


## Cut sounds that are still in the air, because what they were describing is
## over.
##
## THE OTHER HALF OF `suppress`, which only ever worked on a sound that had not
## started. Skipping the jump killed the tween that had the rest of the sequence
## in it and left everything ALREADY PLAYING to run on -- a 5.7-second warp over
## a sector that had finished arriving.
##
## FADED, NOT STOPPED. A stream cut between samples clicks, and on a hyperdrive
## at full level the click is louder than the sound it interrupted. 120 ms is
## under a frame and a half of the sequence being skipped and still long enough
## to land on zero.
##
## A name matches whether it was the one asked for or the take the round robin
## chose, so a caller hushes `thruster_arrive` without knowing which of the eight
## it got.
func hush(names: Array[StringName], fade_ms: int = 120) -> void:
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

func click() -> void:   play(&"ui_click", 0.05)
func hover() -> void:   play(&"ui_hover", 0.09, 40)
func back() -> void:    play(&"ui_back", 0.03)
## The volume check in Settings is its only caller, so it plays a sound the
## game already makes: you hear how loud effects are, not a stinger heard
## nowhere else. ui_confirm was cut after twenty takes missed (sound pass).
func confirm() -> void: play(&"ui_click", 0.02)
func denied() -> void:  play(&"ui_denied", 0.03)

# ---------------- signal handlers ----------------

## The thermal ruling, made audible: ballistics run cold, energy weapons run
## hot. A card that prints heat gets the bright ionised zap; a card that does
## not gets the dry mechanical crack. You hear what a build is made of.
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
	elif c.block > 0 or c.brace > 0 or c.brace_from_heat:
		play(&"shield_block", 0.06)
	# EMERGENCY REPAIR IS THE STATION'S REPAIR, at Jon's ask: the same welding
	# out here as at the berth, because it is the same job done worse.
	elif c.heal > 0 or c.heal_scale > 0:
		play(&"svc_repair", 0.06)
	# LOCK ON is not an attack -- it is the sights closing on one -- so it gets
	# the reticle rather than a gun. Played after the family above, not instead
	# of it: a card that shoots AND locks on is a shot first.
	if c.lock_on > 0:
		play(&"lock_on", 0.05, 120)

## Heat is a second health bar you can choose to spend, and going over costs
## hull, which costs scrap. The warning is edge-triggered on the way up only:
## a tone every time heat moves while already hot would be unbearable across a
## long fight, and would stop meaning anything by turn three.
func _on_combat_state() -> void:
	var cap := Run.heat_cap()
	var hot: bool = cap > 0 and float(Run.heat) >= float(cap) * HEAT_WARN_AT
	if hot and not _hot:
		play(&"heat_warn", 0.02)
	_hot = hot

## Scrap and modules arrive from a dozen places — combat rewards, salvage,
## events, station stock, card effects — and not all of them emit the same
## signal. Chasing every site would mean a sound call in six files that each
## have to remember to keep it; watching the two totals instead means the
## sound is right by construction. One of these two signals always fires
## after anything has changed.
func _poll_resources() -> void:
	var credits := Run.credits
	var cargo := Run.cargo.size()
	if _last_credits >= 0 and credits > _last_credits:
		play(&"scrap_gain", 0.08, 110)
	if _last_cargo >= 0 and cargo > _last_cargo:
		play(&"loot_drop", 0.03, 200)
	_last_credits = credits
	_last_cargo = cargo

## A kill flashes warm and dies cold -- but WHAT died decides the sound.
## Bosses get the two-stage reactor death with the tritone in the debris;
## fauna do not explode at all, because one of the warm things going out is
## a loss even when it was trying to eat you. limit_ms: a card that clears
## a board is one explosion, not a drum roll.
func _on_enemy_destroyed(who: int) -> void:
	var t: EnemyTemplate = null
	if Router.combat != null and who >= 0 and who < Router.combat.enemies.size():
		t = Router.combat.enemies[who].template
	if t != null and t.fauna:
		play(&"fauna_falls", 0.04, 400)
	else:
		# ONE POOL FOR EVERY KILL. Jon: "kill and boss kill can be
		# consolidated." The three boss takes joined the two ordinary ones as
		# round robins of explosion_small, so a boss is not louder or longer
		# than anything else it dies alongside -- and there are five takes
		# rotating instead of two.
		play(&"explosion_small", 0.09, 160)

func _on_damage(_amount: int, to_player: bool, _who: int) -> void:
	if to_player:
		play(&"impact_hull", 0.05)
	else:
		# Your shot landing on THEM: distance runs cold, so it is small and
		# dry. limit_ms keeps multi-hit turns from machine-gunning it.
		play(&"impact_enemy", 0.08, 90)

func _on_combat_ended(result: StringName, _summary: String) -> void:
	# NO STING FOR WINNING. There was one -- Jon cut it outright: "I just don't
	# want the victory sound at all." The kill, the wreck opening and the rarity
	# ladder under it are the reward; a fanfare over them was the game
	# applauding itself.
	match result:
		&"fled": play(&"ui_tab", 0.03)
		_: pass          ## death is handled by run_ended, so it is not doubled

## NOTHING EITHER WAY AT THE END OF A RUN.
##
## WINNING had a sting until Jon cut it: "I just don't want the victory sound at
## all." The kill, the wreck opening and the rarity ladder under it are the
## reward, and a fanfare over them was the game applauding itself.
##
## DYING had one too, once: a two-second sting, F to Gb on a low bowed note. The
## reasoning was sound -- the semitone is the whole idea of the dread cue, so
## dying sounded like the thing that had been following you all run. What it
## actually did was announce the ending over the top of a cue written to BE the
## ending: "No Fault" is a line that falls three times and does not come back up,
## and it does not need help. Silence, and then the music that is already the
## answer.
func _on_run_ended(_won: bool, _reason: String) -> void:
	pass


# ---------------- volume ----------------

func set_volume(bus: StringName, value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	match bus:
		&"Master": master_volume = value
		&"Music": music_volume = value
		&"SFX": sfx_volume = value
	_apply_volumes()
	save_settings()

func volume_of(bus: StringName) -> float:
	match bus:
		&"Music": return music_volume
		&"SFX": return sfx_volume
		_: return master_volume

func _apply_volumes() -> void:
	for pair in [[&"Master", master_volume], [&"Music", music_volume], [&"SFX", sfx_volume]]:
		var idx := AudioServer.get_bus_index(pair[0])
		if idx < 0:
			continue
		var v: float = pair[1]
		# Faders are linear because that is what a slider position means to a
		# player; the bus wants dB. Zero is a mute, not -inf dB.
		AudioServer.set_bus_mute(idx, v <= 0.001)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))

## Shares user://settings.cfg with DisplaySettings, in its own section.
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(DisplaySettings.PATH)            ## keep the display section
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(DisplaySettings.PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(DisplaySettings.PATH) == OK:
		master_volume = float(cfg.get_value("audio", "master", master_volume))
		music_volume = float(cfg.get_value("audio", "music", music_volume))
		sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
	_apply_volumes()
