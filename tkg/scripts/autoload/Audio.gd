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
## ROOM TONE IS PCM WHERE IT LOOPS, and ogg where it is too long to be.
##
## Vorbis has no neighbour for its first and last windows, so it reconstructs
## the very edges of a file wrongly -- inaudible in a cue that ends, and on a
## LOOP it is a click, once a lap, forever. Jon heard it through four rounds of
## me fixing the source and the encoder putting it back. Measured on one build:
## the wav reads x0.4 against the loudest surprise in the lap, the ogg of that
## same wav x53, and still x28 at the encoder's best quality with the length
## unchanged -- so it is the lapped transform, not padding.
##
## The four short rooms are PCM: about 5 MB, and the fault cannot exist. The
## station is six minutes and stays ogg, where its seam is one moment in a
## crowd rather than every few seconds under a hum.
const ROOM_WAV := "res://assets/audio/ambience/%s.wav"
const ROOM_PATH := "res://assets/audio/ambience/%s.ogg"

const OFF_DB := -60.0      ## silent, but still a running player
const SFX_VOICES := 14
## Fraction of heat capacity that counts as "running hot".
const HEAT_WARN_AT := 0.8

var master_volume: float = 0.9
var music_volume: float = 0.7
var sfx_volume: float = 0.9
## ROOM TONE HAS ITS OWN FADER. It used to ride the Music bus -- scenery rather
## than feedback, so it did not belong with the effects -- but that tied the
## reactor, the station and the hypergiants to the score, and a player who
## wants the music down usually does not mean the room with it.
##
## It starts at what Music starts at, so every room is exactly as loud today as
## it was when its level was set: those numbers were tuned by ear through this
## bus at 0.7, and moving the default would quietly retune all five of them.
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
## EACH ROOM AT ITS OWN LEVEL, all of them set by ear and none by arithmetic.
##
## OPEN SPACE is the bed: your own reactor and nothing else, under the score.
## THE THREE STARS are things outside making a noise, a few dB over it. THE
## STATION is neither -- the only room mixed by hand on a bench, and the only
## one the score steps aside for (ROOM_DUCKS), which is how it reads loud while
## measuring quiet.
##
## IN LUFS, NOT RMS, because RMS was wrong about one of them. Jon: "let's have
## blue hypergiant be a tad bit quieter ... the high pitched makes it seem
## louder for some reason." An ear is far more sensitive at 3 kHz than at 60 Hz,
## and the blue room is all top while the others are all bottom: measured by
## ITU-R BS.1770 (`scratchpad/lufs.py`) it was 6.2 dB louder than red and pulsar
## at the same RMS, while those two agreed to 0.2 dB. So the whole family is
## levelled in LUFS now and the RMS column is only there to be read.
##
## THE NUMBERS ARE NOT COMPARABLE BY EYE and must not be edited as if they
## were: each is `target - the file's own measurement`, so a quiet file takes a
## bigger number for the same loudness. Rebuild a room and BOTH its numbers move
## -- the scripts that build them print the pair.
##
##   room      secs   file rms   file LUFS   level      plays at
##   space      5.75     -15.7      -12.0     -14.3    -30.0 rms / -26.3 LUFS
##   blue       7.75     -15.6      -10.2     -14.5    -30.1 rms / -24.7 LUFS
##   red        7.75     -12.7      -13.4      -9.2    -21.9 rms / -22.6 LUFS
##   pulsar     5.00     -13.5      -14.3      -8.5    -22.0 rms / -22.8 LUFS
##   station  360.00     -30.3      -26.5     -15.4    -45.7 rms / -41.9 LUFS
##
## THE STATION MEASURES QUIETER THAN IT DID AND IS NOT. Its announcements left
## the file -- the game deals them now -- so the loud seconds left the average
## with them. The hum, the air, the deck and the crowd are untouched and the
## level is untouched, which is what keeps the announcements sitting exactly
## where they sat when they were baked in.
##
## THE STATION CAME BACK DOWN 4 dB. It went up to -40 rms on Jon's own number,
## and what that actually raised was the REVERB on the announcements: "there is
## sooo much echo now with the PA system". The echo is baked into the bed, so
## the bed is the only dial there is -- a room whose tail is its loudest
## feature gets quiet before it gets dry.
##
## AND THE BLUE ONE HAS ITS TAKES UN-FADED FIRST. Every bought loop tapers,
## even one bought as a loop: its three takes run 8 to 10 dB under themselves in
## their first and last second, so the sum was quiet at both ends. Rotating the
## lap moved that dip instead of fixing it -- into the middle, where the two
## quiet ends landed side by side and dug a 3 dB hole once a lap, which Jon went
## on hearing and calling the seam. The fade now comes off each take at the
## source, and the lap holds within 1.6 dB of itself the whole way round.
##
## THE LENGTHS ARE NOT ROUND ANY MORE, and that is the seam being fixed rather
## than a mistake. Every one of these loops is FOLDED: the end crossfaded over
## the beginning, so the lap finishes in the sound it starts with. Jon heard
## what a plain fold does to tonal material -- "still a dip in volume at the
## seam" -- and he was right: equal power only holds the level when the two ends
## are uncorrelated, and open space is a hum whose ends correlate at +0.85, so
## they partly cancel. `scratchpad/seamless.py` folds, measures the result in
## 20 ms windows and puts the difference back, which fixes a dip and a bump with
## the same arithmetic. The pulsar is folded by exactly ONE BEAT rather than a
## quarter second, so its grid still closes: five passes in five seconds.
const ROOM_LEVELS: Dictionary = {&"amb_space": -14.3, &"amb_blue": -14.5,
		&"amb_red": -9.2, &"amb_pulsar": -8.5, &"amb_station": -15.4}
## [file rms, file LUFS] as the build scripts measured them, and what each is
## meant to land at. The test re-does the arithmetic, because the mistake this
## table invites is editing one number by eye.
const ROOM_FILE_DB: Dictionary = {
		&"amb_space": [-15.7, -12.0], &"amb_blue": [-15.6, -10.2],
		&"amb_red": [-12.7, -13.4], &"amb_pulsar": [-13.5, -14.3],
		&"amb_station": [-30.3, -26.5]}
const ROOM_TARGET: Dictionary = {&"amb_space": -26.3, &"amb_blue": -24.7,
		&"amb_red": -22.6, &"amb_pulsar": -22.8, &"amb_station": -41.9}
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
## THE STATION'S OWN VOICE. The lines it can say, the ones it has not said yet,
## and how long until the next.
const PA_GAP := Vector2(34.0, 68.0)    ## seconds of quiet between lines
const PA_FIRST := Vector2(6.0, 16.0)   ## and before the first one, after docking
var _pa: AudioStreamPlayer = null
var _pa_lines: Array = []
var _pa_bag: Array[int] = []
var _pa_next: float = 0.0
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
	# the idle bed decides on a headless run too, so a test can read it
	_idle_clock = IdleClock.new()
	_idle_clock.audio = self
	add_child(_idle_clock)
	# a harness's (or Jon's) choice of take per moment: `fx=row:choice,...`;
	# `sfxtape=<json>` tapes every sound and writes the tape at exit, with the
	# frame each was drawn on (for laying a film's events against its sound)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("fx="):
			_fx_args(a.substr(3))
		elif a.begins_with("sfxtape="):
			_tape_to = a.substr(8)
			taping = true
	# The balance sim boots the whole project so the autoloads exist. It runs
	# hundreds of combats with no window and no audio device, and loading 36 MB
	# of streams for it would be pure cost. Same guard Main.gd uses.
	if "sim" in OS.get_cmdline_user_args():
		_enabled = false
		return
	# HEADLESS IS SILENT BUT STILL WIRED, so a harness that tapes can read what
	# would have played and when (`_dry_play`); untaped, every call returns at
	# once.
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
	# ON THE FRAME THE SHOT ARRIVES, not when the maths ran. `damage_dealt`
	# fires as the card resolves, which is before the tracer has crossed the
	# gap -- so every impact played 8 to 17 frames ahead of the hit it belonged
	# to, and a kill stacked five sounds on the release frame (combat polish
	# audit F1). The screen says when a shot is seen landing.
	Sig.hit_landed.connect(_on_hit_landed)
	# THE RELEASE of a charged card is a heavy shot, because that is what it is.
	# It used to play `charge_fire` here and the heavy shot on PLAY -- a gunshot
	# at the one moment nothing fires. Jon: "there should be a charging sound
	# and a release sound. separate." The charging half is in _on_card_played.
	Sig.charge_fired.connect(func(_n: String) -> void: play(&"shot_heavy", 0.05))
	# (overheat: played by the fight's screen when the burn is shown, on the
	# same frame as the hull it costs -- see SectorScreen._show_burn)
	# NO STING WHEN A FIGHT STARTS. The music already tells you: combat moves the
	# cue to Hard Burn, which is 160 BPM of sixteenths against everything else in
	# the soundtrack. A sting on top of that is the score saying the same thing
	# twice, half a second apart, and the second one is louder.
	Sig.combat_ended.connect(_on_combat_ended)
	# NO SOUND ON Sig.jumped. It played `jump`, the convoy's bang, and the
	# player's own departure had to suppress it under the drive and the flare
	# -- which play their own. Jon cut `jump` in the sound pass: "Just use the
	# jump out sound." The convoy plays `hyperjump` itself (EncounterView).
	# (a kill: played by the fight's screen on each visible break of the hull,
	# `ShipBreakup.broke`, rather than when the last hit was resolved -- see
	# `play_kill`)
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
	# (the draw: played by the fight's screen when the new hand is dealt, which
	# is after the enemy's turn has played out on screen, not when it resolved)
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

## The last state the game asked the music for, kept even with audio off, so a
## headless harness can say which cue a screen wired (`-- sheet=CoreWinTest`:
## the win screen asks for &"gameover", the death screen's Lights Out).
var music_asked: StringName = &""

func music_state(state: StringName) -> void:
	music_asked = state
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
## A room's tone loaded ahead, off the main thread, so `room` finds it ready (the
## yard built ahead for 3B's dock: loading the tone at the swap was 26 ms of the
## move's one frame).
func warm_room(name: StringName) -> void:
	if not _enabled or name == &"" or name == _room_now:
		return
	var path := ROOM_WAV % name
	if not ResourceLoader.exists(path):
		path = ROOM_PATH % name
	if ResourceLoader.exists(path) and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path)


## LOOP A ROOM TONE ON ITS WHOLE LENGTH, seamlessly (this, `LabScene` and
## `YardSound`). ONE FRAME SHORT OF THE END, AND PCM (the rooms' imports say
## compress/mode=0). Looped at the frame count, Godot's player reads a frame past
## the data at every lap, and the QOA the rooms were imported as also restarts
## its decoder wrong at the wrap: rendered through `mix_audio`, amb_red's seam
## stepped 128 times its typical sample step, amb_pulsar 112, amb_space 30, a
## click every lap (every 7.75 s on a red star, one of them half a second before
## A.S.H.'s fade in her film). PCM and frames - 1 measure 2 to 4.4 on all ten
## looped rooms, which is the files' own seams. `-- sheet=AshTest` holds it.
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
	# Seamless on its own length, so tell the stream that rather than letting it
	# stop at the end of the file and leave the place silent for the rest of a
	# visit. Both kinds need telling, and they ask for it differently.
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


## Where the room tone `name` is in its loop, in seconds, as heard: the
## player's position plus the time since the last mix, less the output latency.
## -1 if that room is not the one playing. The system map keeps the pulsar's
## beam on the passes of `amb_pulsar` with it.
func room_clock(name: StringName) -> float:
	if _room == null or not _room.playing or _room_now != name:
		return -1.0
	return _room.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()


## THE STATION DEALS ITS OWN LINES NOW.
##
## Six announcements used to be baked into the six-minute bed at fixed offsets,
## which meant every dock heard the same six of the sixteen, in the same order,
## at the same moments. Jon: "Can we randomize the PA speech? I don't want it to
## be in the same order every time." Nothing at runtime can shuffle a mixdown,
## so `station.py --split` renders the bed with the PA silent and writes all
## sixteen lines as their own files, each at exactly the amplitude it had in the
## bed. The balance is the same arithmetic; only the order is free.
##
## The sidecar changed meaning with it: it used to say WHEN the bed talks, and
## now it says WHAT there is to say.
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


## The next line, and never the same one twice until every one has been heard.
##
## A BAG, NOT A ROLL. Sixteen lines drawn at random repeat about one dock in
## eight -- and a repeat inside a minute is the one thing that says "this is a
## short list" louder than the old fixed order did.
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





## THE FADE IS AN ARGUMENT BECAUSE THE QUIT NEEDS A DIFFERENT ONE. Everywhere
## else this is one cue leaving as another arrives, and SWAP's two and a half
## seconds is right for that. At the shutdown it is not a swap at all -- it is
## the power going -- and Jon heard the difference: "after the snap lands the
## music should stop. it continues for a bit afterward." It was still playing,
## and still bending down in pitch, for 2.5 s after the click.
func stop_music(secs: float = SWAP) -> void:
	if not _enabled:
		return
	_cue = &""
	for i in _mv.size():
		_ramp(i, 0.0, secs)


## THE SET TAKES THE SOUND DOWN WITH IT. Jon: "the music should maybe warp down
## in pitch as the tv closes? like it's being shut down."
##
## A FADE IS A MIXER; A PITCH DROP IS A MACHINE. Turning the volume down says
## somebody moved a fader. Bending the pitch down says the thing PLAYING it is
## losing speed, which is the only reading that matches a picture folding into a
## line -- and it is what tape and a film projector actually do when the power
## goes, which is where the ear learned it.
##
## EVERY VOICE, INCLUDING THE ROOM. If the music slows and the reactor hum does
## not, the hum becomes the one thing in the mix that is not dying, and it reads
## as a music effect rather than as the set going off.
##
## ONE WAY ONLY. Nothing restores this, because the only caller is the quit and
## the process is about to end. A harness that wants the game afterwards should
## not be calling it.
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
## THE MUSIC STEPS BACK for a set piece (a boss's death, `ScreenHooks`): down
## by `amount` (0..1 of the way to silence, in level) for `secs`, on the same
## eased duck as an announcement.
var _scene_duck_until := -1.0
var _scene_duck_to := 1.0

func duck_music(amount: float, secs: float) -> void:
	_scene_duck_to = clampf(1.0 - amount, 0.05, 1.0)
	_scene_duck_until = GameClock.now() + secs


## A MUSIC HIT at a set piece's peak. There is no stinger yet (Jon cut the old
## stings), so this is asked for, counted and taped, and silent until one is
## made; `stingers_asked` lets a harness see it was.
var stingers_asked := 0

func music_stinger(strength: float) -> void:
	stingers_asked += 1
	if taping:
		tape.append([&"music_stinger", Time.get_ticks_msec(), linear_to_db(maxf(0.01, strength)), 1.0])


func cue() -> StringName:
	return _cue


# ---------------- A.S.H.'s voice ----------------
## HER VOICE (`AshPortrait` asks; `AshLines.VOICE` names the takes): one line at
## a time on a player of its own, so a line never steals an effect's voice from
## the pool or has one stolen from it, on the SFX bus -- she is the ship
## talking, and the EFFECTS slider is the ship's own sounds. Ogg, not WAV like
## the effects: a line is seconds long and never loops, so the codec's edges
## (the reason looping room tone is PCM) never meet.
##
## HER LEVEL is set against the in-game mix, measured off the movie writer's
## `f.wav` (`-- sheet=AshFilm`): the takes are levelled to -18.3 LUFS, and
## VOICE_DB puts her where the measurement says (`docs/ash.md`, "Her voice").
const VOICE_DB := -4.0
## THE SCORE STEPS ASIDE FOR HER, a little: -4 dB on every music stem while a
## line plays, on the announcement duck's own ramp (`DUCK_IN` / `DUCK_OUT` per
## whole unit of level, so -4 dB goes down in 0.13 s and back in 0.44 s). Asked
## every frame off the player, like the station's PA, so a line cut short lets
## the music up from that frame.
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


## Say the take at `path`. Returns its length, s (0 if it will not load). Taped
## (`taping`) as `ash/<name>` even where nothing plays: headless and harness
## runs hear nothing, and a test reads the tape.
func ash_voice(path: String) -> float:
	var stream := load(path) as AudioStream if ResourceLoader.exists(path) else null
	if stream == null:
		push_warning("Audio: missing voice %s" % path)
		return 0.0
	var secs := stream.get_length()
	voice_now = path
	_voice_end = GameClock.now() + secs
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
	_voice.stream = stream
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
	if not _enabled:
		return
	# ASKED EVERY FRAME, NOT FIRED ON AN EVENT. Whether a line is playing is a
	# fact about the playhead, so reading it each frame is both simpler than
	# scheduling six timers against a loop and immune to a missed edge: tab away
	# mid-sentence and come back and the duck is simply correct, where a timer
	# would be stuck down until the next announcement let it up.
	# THE STATION'S CLOCK. It only runs while its room is the one playing, so
	# leaving the station stops the talking with it rather than letting a line
	# arrive over open space.
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
## `pitch` is the note the spread is taken round (A.S.H.'s power-on plays the
## text blip twice, the second a minor third up: `AshPortrait`).
func play(name: StringName, pitch_var: float = 0.06, limit_ms: int = 0,
		db: float = 0.0, pitch: float = 1.0, from: float = 0.0, exact: bool = false) -> void:
	# (headless there is no sound, but a harness taping still gets the decision:
	# everything below down to the pick, then `_dry_play`)
	if not _enabled and not taping:
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
	# `exact`: this take and no other (a pool that levels its takes one by one,
	# `Audio.FX` `pool`, names each; `explosion_small` alone would round-robin)
	var vars: Array = [name] if exact else _variants.get(name, [])
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
	# WHATEVER THIS VOICE WAS DOING, IT IS NOT DOING IT NOW. A hush left a tween
	# pulling this player's volume toward silence; reusing it without killing
	# that would start the new sound and fade it out underneath itself.
	if _fade[_sfx_next] != null and _fade[_sfx_next].is_valid():
		_fade[_sfx_next].kill()
	_fade[_sfx_next] = null
	_sfx_next = (_sfx_next + 1) % _sfx.size()
	p.stream = stream
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_var, pitch_var))
	p.volume_db = db
	# WHAT THIS VOICE IS CARRYING, so `hush` can find it again. The pick, not the
	# name asked for -- a round robin plays `thruster_arrive_c` when the caller
	# said `thruster_arrive`, and a hush naming either has to land.
	p.set_meta(&"cue", pick)
	p.set_meta(&"asked", name)
	p.set_meta(&"t0", Time.get_ticks_msec())
	if taping:
		tape.append([pick, Time.get_ticks_msec(), db, p.pitch_scale, GameClock.now(),
			Engine.get_process_frames(), name, from])
	p.play(from)

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

## AT MOST `cap` OF ONE SOUND IN THE AIR. The event text's blip (`SignalText`)
## lands on every third letter, about eleven a second at 40 cps, and each rings
## for 0.3 s, so left alone four would stack. The Lead's rule is never more than
## two at once. Before a new one starts, the oldest still playing at the cap is
## faded out over `steal_ms`. It fades rather than stops, for the reason `hush`
## gives. The new one still plays, so the rhythm Jon picked on the audition page
## is kept; only the tails get shorter. A voice already fading does not count.
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
## The volume check in Settings is its only caller, so it plays a sound the
## game already makes: you hear how loud effects are, not a stinger heard
## nowhere else. ui_confirm was cut after twenty takes missed (sound pass).
func confirm() -> void: play(&"ui_click", 0.02)
func denied() -> void:  play(&"ui_denied", 0.03)


# ---------------- the effects' moments ----------------
##
## OCTOBER'S EFFECTS WERE SILENT (the sound plan of Oct 17, scratchpad
## `sfx-plan/plan.json`). Every one of them already said when it acts -- a
## `moment(kind, strength, length)` from ShipHitFx, ShieldFx, BraceFx and
## ShipBreakup -- and the one listener played two of them. Now each is heard on
## the frame its picture acts: first with files the game already had (the free
## pass), then with the ElevenLabs takes Jon picked by ear (Oct 17), copied into
## `sfx/` under the plan's names (`brace_clang` and `brace_clang_2` are his
## A1 and A2, alternated as round robins).
##
## ONE ROW PER MOMENT, AND EVERY ROW IS SWITCHABLE. `pick` is what plays;
## `free` the free pass's pick where a bought take replaced it; `before` what
## played there before any of this (empty: nothing did); `off` silence. On the
## command line `fx=brace_on:free`, `:before`, `:off`, or a file of its own
## (`fx=brace_on:brace_on_b@-3[@offset]`); the same under `[fx]` in
## settings.cfg. `fx=all:before` puts every row back as it was.
##
## In a row's take:
##   file    the sfx played (round robins as `play` finds them)
##   db      its level against its peers (the bought takes are levelled to the
##           plan's targets already, so 0 unless the row says why not)
##   at      the moment kind it lands on, where the caller sees more than one
##           (bolt_on starts the plates, clamp locks them 0.35 s later)
##   offset  s: later than the moment (> 0, on the game's clock) or that far
##           into the file (< 0), to put a file's own hit on the picture's
##   end_on  started far enough into the file that it runs out as the moment's
##           length does: a whine into the blast it leads to
##   limit   s on the game's clock between two of this row: never chatters
##   cap     at most this many of the file in the air (`play_capped`)
##   pitch   the round robin's pitch spread (0.05 if not given)
##   hush    a name to keep quiet instead of a sound (`suppress`)
##   duck    how far the music steps back, for the caller's length
##   bed     a loop (`ambience/` or `sfx/`) faded in, held until `fx_stop`
const FX: Dictionary = {
	# A SHIP'S DEATH, HEARD AS ONE (Jon, Oct 19, of a hulk's: "the ship exploding
	# at the end of that video is weak"). Measured (`scratchpad/death-punch/`):
	# the kill pool's five takes spread 5 dB -- explosion_small and _2 are 4 dB
	# under a plain hit landing (momentary max -17.6 / -17.2 against
	# impact_enemy's -13.8), _3 to _5 the old boss takes (-12.6 to -14.9) -- so
	# a death came out as loud as a round robin's luck, and a D under the hit
	# that caused it. Its MAIN BREAK (`broke` at 0.6 or more, on the frame the
	# picture bursts) is now three layers: the three heavy takes alone, each
	# levelled to -12.8 (`pool`, a take and its own offset); a sub thump, the
	# first impact_hull (80% of it under 90 Hz, gone in 0.45 s), down 6; and
	# hull_crunch's buckling metal, down 4. Together about 1.5 dB over a hit's
	# impact and level with a hit's whole volley (card, shot and impact), every
	# look within about a dB of the others, peaks under -0.5 dBFS (_3 a touch
	# lower for it). The
	# lesser breaks (a burst before the break, a prelude) are the two short
	# takes, down 3. `before` is the one pool as it was.
	&"kill_boom": {pick = {pool = [[&"explosion_small_3", -0.9], [&"explosion_small_4", 2.1],
				[&"explosion_small_5", -0.2]], db = 0.0, limit = 0.2, pitch = 0.05},
			before = {file = &"explosion_small", db = 0.0, pitch = 0.09}},
	&"kill_thump": {pick = {pool = [[&"impact_hull", 0.0]], db = -6.0, limit = 0.2, pitch = 0.03}, before = {}},
	&"kill_crunch": {pick = {file = &"hull_crunch", db = -4.0, limit = 0.2, pitch = 0.05}, before = {}},
	&"kill_pop": {pick = {pool = [[&"explosion_small", 0.0], [&"explosion_small_2", -0.4]], db = -3.0, limit = 0.12, pitch = 0.08},
			before = {file = &"explosion_small", db = -6.0, pitch = 0.09}},
	# CREATURE DEATHS N, O, P. Jon picked the three takes on Sep 19 and nothing
	# ever reached them: `play_kill` routed fauna to them, but only a ship's
	# breakup said `broke`. On the death's first beat (the flare, or P's pulse).
	# They measure -10 to -15 LUFS against explosion_small's -15 to -21.
	&"fauna_death": {pick = {file = &"fauna_falls", db = -4.0, limit = 0.4}, before = {}},
	# PLATING GOING ON (an enemy's, and yours): Jon's B1, a bolt driver's three
	# bangs and a latch, from the wave's start so the latch is the clamp. The
	# free pass had module_install; before that, a shield's sound on armour.
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
	# GAS LEAVING THE HULL: death G's two jets and a vent's opening burst (Jon's
	# gas_vent A1, -24 LUFS), and the sputters (gas_puff C1, -34), never closer
	# than 0.4 s whatever number of vents are open. The free pass used `vent`.
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
	# THE FIGHT'S BAND, up as the fight opens and down as it ends. Jon: "the
	# drawer sliding up sound and closing sound should be the same as the esc
	# menu opening and closing" -- its own files at its own level
	# (`Main.toggle_menu`: 0 dB). The free pass had hold_lift up, nothing down.
	&"fight_band": {pick = {file = &"menu_open", db = 0.0, pitch = 0.03},
			free = {file = &"hold_lift", db = -4.0, pitch = 0.03}, before = {}},
	&"fight_band_down": {pick = {file = &"menu_close", db = 0.0, pitch = 0.03}, before = {}},
	# YOUR SHIP LOST: the set going off as the picture goes, the score down
	# through the gap after the breakup, and no page click on the swap; and the
	# breakup's prelude of bursts whining up into the ship's own death (Jon's
	# charge_whine A1, from the first burst, ending as the style begins 1.5 s in).
	&"loss_handoff": {pick = {file = &"power_off", db = 0.0, pitch = 0.0}, before = {}},
	&"loss_duck": {pick = {duck = 0.6}, before = {}},
	&"loss_swap": {pick = {hush = &"ui_tab"}, before = {}},
	&"charge_prelude": {pick = {file = &"charge_whine", db = 0.0, offset = 0.7, limit = 3.0, pitch = 0.0}, before = {}},
	# THE HELLBENDER HEATING: the red hypergiant's furnace, faded in as the
	# device heats (1.5 s) and out as it bursts (5.6 s).
	&"hb_heat": {pick = {bed = &"amb_red", db = -13.0, fade_in = 0.6, fade_out = 0.4, at = &"emblem_heat"}, before = {}},
	# THE BOSSES' SMALL BREAKS: the Hellbender's holds and its cargo popping (the
	# kill pool, low); the Custodian C1c's spine pops, glass cracking (Jon's
	# glass_crack B2, the Custodian's cracks); C1c's split, glass shattering
	# (glass_shatter A1). The free pass played the kill pool for all three.
	&"boss_pop": {pick = {file = &"explosion_small", db = -10.0, limit = 0.08, pitch = 0.09}, before = {}},
	&"spine_pop": {pick = {file = &"glass_crack", db = 0.0, limit = 0.08, pitch = 0.06},
			free = {file = &"explosion_small", db = -10.0, limit = 0.08, pitch = 0.09}, before = {}},
	&"boss_split": {pick = {file = &"glass_shatter", db = 0.0, pitch = 0.0},
			free = {file = &"explosion_small", db = 0.0, pitch = 0.09}, before = {}},
	# THE SHIELD AT REST: one hum while any hex shield is up and seen (Jon's
	# shield_idle_bed A1, -46 LUFS, a PCM loop), however many ships hold one --
	# a room of shields is not louder, it is the same field -- faded with it.
	&"shield_idle": {pick = {bed = &"shield_idle_bed", db = 0.0, fade_in = 0.3, fade_out = 0.3}, before = {}},
	# ITS RIPPLES AND GLITCHES (about 43 a minute a shield): a crackle (Jon's
	# shield_glitch A1, -36), never closer than half a second, one at a time.
	&"shield_glitch": {pick = {file = &"shield_glitch", db = 0.0, limit = 0.5, cap = 1, pitch = 0.08}, before = {}},
	# A HULL BUCKLING (Jon's hull_crunch A1, -24): death M's four crunches on
	# their own grid (0, 0.20, 0.38, 0.54), which were explosions; and a crack
	# in a hit's marks, under the impact (down 6: it lands with impact_enemy or
	# impact_hull). Death A's crack is every main break's buckling layer now
	# (`kill_crunch`), so it has no row of its own.
	&"crumple": {pick = {file = &"hull_crunch", db = 0.0, limit = 0.1, pitch = 0.05}, before = {}},
	&"crack_mark": {pick = {file = &"hull_crunch", db = -6.0, limit = 0.3, pitch = 0.06}, before = {}},
	# A CHARGE WHINING UP INTO ITS BLAST (Jon's charge_whine A1, -26): D's
	# charge, F's spool, C's gather, each started so it runs out as the blast
	# lands (that blast keeps its explosion).
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
	# GLASS CRACKING (Jon's glass_crack B2): the Custodian's eight cracks on
	# their own times (which were eight explosions), K's shield shattering
	# (which was one), and a creature's scales shedding (down 6, under its hit).
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


## THE MOMENT `row` NAMES HAS HAPPENED ON SCREEN, this frame. `kind` is the
## picture's own name for it (a row with `at` plays on that kind only); `secs`
## is how long a duck holds. True if the row sounded (or will, `offset`).
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
##
## ONE PLAYER A ROW, so the Hellbender's furnace, the Custodian's arcs and a
## shield's hum are each their own and none cuts another off. A row's bed is
## up from its `fx` until its `fx_stop` (or `fx_hold` false), faded both ways.
## `bed` names a room tone (`ambience/<bed>.wav`) or an effect's loop
## (`sfx/<bed>.wav`); either is looped on its whole length, as `room` loops.
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
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * float(stream.mix_rate))
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
##
## A harness without a window has no Audio at all (`_ready`), so a test of
## WHEN a sound plays had nothing to read. While `taping`, `play` runs its rate
## limits, suppression and pick and tapes the result here instead; the voices it
## would hold are kept as lengths, so `play_capped`'s cap can be read too.
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
	elif c.block > 0:
		play(&"shield_block", 0.06)
	# BRACE IS PLATING, NOT A SHIELD: its sound is the plates going on, played
	# by the picture when they do (`SectorScreen._on_fx_moment`, `brace_on_yours`).
	# Here only if that row is set back to what it was.
	elif c.brace > 0 or c.brace_from_heat:
		fx(&"brace_on_yours", &"card")
	# EMERGENCY REPAIR IS THE STATION'S REPAIR, at Jon's ask: the same welding
	# out here as at the berth, because it is the same job done worse. The
	# berth's repair is the Yard's drones at work now (`yard_repair_*`, quiet
	# and distant); this keeps the welding the berth used to play.
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
## A ship's breakup breaking, on the frame it does (`ShipBreakup.broke`): its
## main break (`s` 0.6 or more) the layered boom, a lesser one a pop. A
## creature never breaks (its first beat is `play_kill`'s).
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
		# ONE POOL FOR EVERY KILL. Jon: "kill and boss kill can be
		# consolidated." The three boss takes joined the two ordinary ones as
		# round robins of explosion_small, so a boss is not louder or longer
		# than anything else it dies alongside -- and there are five takes
		# rotating instead of two.
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
## YOUR SHIP ON THE SECTOR MAP, heard (Jon: "the ship should use the thruster
## sounds when it moves? Maybe a bit quieter?"): the same drive LOCAL plays, this
## much quieter, because it is a small thing on a big map and you hear it a lot.
const SHIP_DB := -8.0
## THE THRUST LOOP, held while a thrust key is: a second of the arrival clip's
## clean burn (constant rate and level), its last 0.15 s folded over its head so
## the seam is continuous, and PCM so no codec touches the join. Low-passed at
## 1.2 kHz around its own period (the burn is all under 1 kHz; a tick 0.65 s in
## clicked once a loop, Jon: "clicks in between the loops"). 44101 frames, the
## last a copy of the first: the import loops at frames-1 (loop_end -1), so the
## loop is exactly 44100 and the copy is only read as the interpolation partner.
const SHIP_LOOP := &"ship_thrust_loop"
var _ship_loop: AudioStreamPlayer = null
var _ship_level := 0.0
var _ship_depart: AudioStreamPlayer = null
var _ship_arrive: AudioStreamPlayer = null


## The loop's level, every frame the map runs: 0.7 thrusting, 0.45 braking, 0.32
## turning or nudging an orbit, 0 for nothing. Fades in fast and out slower.
func ship_thrust(level: float) -> void:
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
	var dt := get_process_delta_time()
	var tc := 0.03 if level > _ship_level else 0.08
	_ship_level += (level - _ship_level) * (1.0 - exp(-dt / tc))
	_ship_loop.volume_db = -80.0 if _ship_level < 0.002 else SHIP_DB + linear_to_db(_ship_level)


## THE MAP LEFT: the burn faded out in a tenth of a second (a frame of
## `ship_thrust(0)` only eases it, and no frame follows).
func ship_thrust_off() -> void:
	_ship_level = 0.0
	if _ship_loop != null and _ship_loop.volume_db > -79.0:
		create_tween().tween_property(_ship_loop, "volume_db", -80.0, 0.1)


# ---------------------------------------------------------------- the idle
## YOUR ENGINES AT IDLE, HEARD (Jon, Oct 13: "Let's have a low burn sound for
## the idle engines"). A bed you notice when it stops: it plays exactly while
## your ship's idle flame is on screen and fades with it. The view that is your
## ship on LOCAL and in fights (`ShipView.hums`) hands itself in, and this asks
## it every frame (`ShipView.idle_heard`) -- the same reasoning as the duck in
## `_process`: a fact about the picture, read each frame, cannot miss an edge.
## So the arrival's clean burn is the clip alone and the bed comes up under the
## first gap after it; a hyperdrive's dark, a departure, a screen without your
## ship (or a view freed with its screen) all take it down the same way.
##
## THE BED: the map's thrust loop pitched down a fourth and low-passed, a soft
## low rumble (`audio/idle_bed.py` makes it from audio already in the game and
## says how the loop is made seamless). Jon picked it from three, Oct 13: "bed:A";
## the others were a darker re-cut of the heavy arrival's burn and a sparse
## burble at the flame's 8 a second. git has them.
const IDLE_LOOP := &"ship_idle"
## Where it sits, measured, not guessed. Mastered to -20 dBFS RMS; at IDLE_DB it
## is -44 LUFS as heard: 16 LU under the map's thrust loop as it is heard
## (SHIP_DB at 0.7, -28 LUFS), about 11 under a UI click's 400 ms loudness (-33)
## and 24 under a hit on your hull (-20). It was -17 (-40 LUFS); Jon picked the
## quieter of three levels ("level:C"), 4 dB down.
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


## AFTER THE PICTURE, NOT BEFORE IT. This autoload processes ahead of every
## screen, so asking the view from `_process` read the frame before: the bed
## came up a frame after the flame dropped to the idle (`-- sheet=IdleSoundTest`
## caught it). Its own node, last in the frame, reads the frame being drawn.
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
		# HELD WITH THE GAME: the bed is part of the picture, so a paused tree
		# pauses it where it is. (Nothing pauses the tree today -- the escape
		# menu overlays a turn-based game -- and the flame keeps drawing behind
		# it, so the bed keeps playing there too.)
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


## A FLIGHT, HEARD: the departure burn as it sets off, and an arrival flameout
## (a row picked as `ShipView.arrive` picks one, the hull's weight picking the
## clip) started at the point in it where its clean burn ends 0.08 s before the
## ship settles, so the stutter plays over the settling. On a transfer orbit the
## departure burn is short and the coast between is quiet; on the swoop the two
## crossfade.
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
		tw.tween_property(_ship_depart, "volume_db", -80.0, 0.2 if conic else 0.3 * dur)
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
