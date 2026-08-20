extends Node
## Music and sound.
##
## Music is vertical, not horizontal. A cue is not one file: it is eight or
## nine stems that all start on the same sample, and `intensity` decides how
## many of them you can hear. Nothing restarts when a fight begins — the
## arrangement opens up. That is why the transition costs nothing, never loses
## the beat, and cannot land you in the wrong bar.
##
## All eight cues are tempo-locked on purpose. Every one is 142 BPM or exactly
## half at 71, so any bar line in any cue lands on a bar line in any other and
## a crossfade never needs a tempo match. All eight are rendered as seamless
## loops — no fade, reverb tail wrapped back over the head — so they can run
## indefinitely.
##
## They are also one piece of music. Every cue is the same whistled five-note
## motif, and each does exactly one thing to it. Five recolour it in place:
## "Dead Sector" flattens the 2nd, "Hard Burn" halves its note values and
## builds the engine out of it, "Warm Ship" finally gives it the fifth it
## never reaches, "Poisoned Ground" gives it that fifth a semitone flat.
##
## The last three develop it instead of recolouring it, because five cues of
## one tonic is a lot of F. "Nine Shells" transposes it around the minor-third
## cycle; "Ship's Business" runs it through a circle of fifths and is the
## first music here with a cadence in it; "Five Ways Home" varies it five ways
## and turns it major. Between them they are the first cues in the game to
## change key at all.
##
## Composition lives in `audio/THEME_NOTES.md` and `audio/DREAD_NOTES.md`;
## the forms themselves in `audio/motif.py`; the render and encode pipeline in
## `audio/README.md`.

const MUSIC_DIR := "res://assets/audio/music/%s/%s.ogg"
const SFX_PATH := "res://assets/audio/sfx/%s.wav"

## Layer tables, straight from THEME_NOTES §5 and DREAD_NOTES §4. A stem joins
## at its intensity and never leaves, so raising intensity only ever adds.
const CUES := {
	## Three rungs, not five. It used to climb to "contact" and "combat" on
	## `lead` and `perc`, but combat moved to `burn` and bosses to `boss` — the
	## crossfade between two cues over the shared F pedal reads as the place
	## turning, which is worth more than the same cue getting louder. STATES has
	## asked for this one at rung 2 and rung 0 ever since, so the top two rungs
	## were stems nothing could reach. `arrange.py` still renders them for the
	## concert master; `build.py`'s UNSHIPPED keeps them out of the download.
	&"theme": [
		[&"whistle", &"pad"],       ## 0  menu, title, the run is over
		[&"bass", &"fx"],           ## 1  idle: chart, refit, station
		[&"arp", &"bell"],          ## 2  out in a sector
	],
	&"dread": [
		[&"sub", &"fx"],            ## 0  something is wrong here
		[&"drone", &"pad"],         ## 1  deep, and it is not safe
		[&"motif", &"pulse"],       ## 2  being hunted
		[&"bowed", &"metal"],       ## 3  it has found you
		[&"cluster"],               ## 4  tritone: the kill state
	],
	&"burn": [
		[&"pad", &"fx"],            ## 0  something is out there
		[&"sub", &"motif"],         ## 1  it has seen you
		[&"riff", &"arp"],          ## 2  weapons free
		[&"perc", &"bell"],         ## 3  the fight proper
		[&"stab"],                  ## 4  all of it
	],
	&"warm": [
		[&"pad", &"fx"],            ## 0  docked, lights low
		[&"glass", &"sub"],         ## 1  inside the ship: refit, deck
		[&"motif", &"arp"],         ## 2  station, services open
		[&"bell"],                  ## 3  spare rung, for events at a station
		[&"lead"],                  ## 4  the motif, answered
	],
	&"boss": [
		[&"sub", &"fx"],            ## 0  the ground is wrong
		[&"drone", &"pad"],         ## 1  tritone pedal
		[&"motif", &"pulse"],       ## 2  the theme, untouched, over it
		[&"bowed", &"metal"],       ## 3  as far as a deep-space fight gets
		[&"shadow"],                ## 4  bosses only: both mutations at once
	],
	## The last three cues are single-state screens — there is no fight to
	## escalate — so they get three fat rungs instead of five thin ones. The
	## ladder is for combat; spending stems on a ladder nothing climbs just
	## costs download size. play_cue() clamps to the table, so a short cue is
	## a supported cue and not a special case.
	&"shells": [
		[&"pad", &"fx"],            ## 0  the void, planing
		[&"motif", &"harp"],        ## 1  chart: the tune and its figuration
		[&"reed", &"bell"],         ## 2  full
	],
	&"business": [
		[&"strings", &"fx"],        ## 0  a quartet, waiting
		[&"bass", &"motif"],        ## 1  the period
		[&"hammer", &"reed"],       ## 2  full: keyboard and wind
	],
	&"home": [
		[&"strings", &"fx"],        ## 0  the theme, bare
		[&"whistle", &"hammer"],    ## 1  the variations proper
		[&"reed", &"glass"],        ## 2  full
	],
}

## Where a screen sits on the ladder. Router names the state; this is the only
## table that decides what it sounds like, so retuning the whole game's music
## pacing is a one-file edit.
const STATES := {
	&"menu":     [&"home", 2],
	&"chart":    [&"shells", 2],
	&"ship":     [&"warm", 1],
	&"station":  [&"warm", 2],
	&"sector":   [&"theme", 2],
	&"event":    [&"business", 2],
	&"combat":   [&"burn", 4],
	&"boss":     [&"boss", 4],
	&"gameover": [&"theme", 0],
}

## Deep space swaps a cue for its darker counterpart at the same rung. Both
## pairs share a common F pedal and an exact tempo lock and differ by one note
## of the motif, so this reads as the *place* turning rather than as the music
## changing. DREAD_NOTES §5, "sector transition".
const DEEP := {
	&"theme": &"dread",
	&"burn": &"boss",
	&"business": &"dread",
}
## States the swap applies to. A station or the star chart sounds the same
## wherever you are; a place you are standing in does not.
const DEEP_STATES: Array[StringName] = [&"sector", &"combat", &"event"]
## Deep space never unlocks a cue's top rung. On "Poisoned Ground" that rung is
## the theme and the dread cue stated simultaneously, which is the boss reveal
## — so a danger-10 skirmish must not spend it first.
const DEEP_MAX := 3

## Danger at which a sector stops using the main theme and switches to the
## dread cue. The galaxy runs 1-10 and gets worse coreward, so this is the
## point where the soundtrack admits it.
const DREAD_DANGER := 8

const FADE := 1.4          ## seconds to bring a layer in or out
const CROSSFADE := 2.2     ## seconds to swap cues
const OFF_DB := -60.0      ## a stem that is "off" is silent, not stopped
const SFX_VOICES := 14
## Fraction of heat capacity that counts as "running hot".
const HEAT_WARN_AT := 0.8

var master_volume: float = 0.9
var music_volume: float = 0.7
var sfx_volume: float = 0.9

var _stems: Dictionary = {}         ## cue -> {stem: AudioStreamPlayer}
var _gain: Dictionary = {}          ## cue -> float, whole-cue crossfade gain
var _gain_target: Dictionary = {}
var _cue: StringName = &""
var _intensity: int = 0
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _cache: Dictionary = {}
var _last: Dictionary = {}          ## sfx name -> msec, for rate limiting
var _enabled: bool = true
var _last_credits: int = -1
var _last_cargo: int = -1
var _hot: bool = false
var _running: Dictionary = {}       ## cue -> bool, are its players rolling

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
	_connect_signals()

## Systems emit on Sig and never reach across scenes, so this is where the
## whole game's sound wiring lives — one place to read, one place to retune.
func _connect_signals() -> void:
	Sig.card_played.connect(_on_card_played)
	Sig.damage_dealt.connect(_on_damage)
	Sig.charge_fired.connect(func(_n: String) -> void: play(&"charge_fire"))
	Sig.overheated.connect(func(_b: int) -> void: play(&"overheat"))
	Sig.combat_started.connect(func(_n: String) -> void: play(&"combat_start"))
	Sig.combat_ended.connect(_on_combat_ended)
	Sig.jumped.connect(func(_i: int) -> void: play(&"jump"))
	Sig.ship_changed.connect(func() -> void: play(&"module_install", 0.04, 120))
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

## Router calls this on every screen change. Unknown states are ignored rather
## than silencing the music, so a new screen is never a silent screen.
func music_state(state: StringName) -> void:
	if not _enabled or not STATES.has(state):
		return
	var entry: Array = STATES[state]
	var cue: StringName = entry[0]
	var level: int = entry[1]
	if DEEP.has(cue) and state in DEEP_STATES and _danger() >= DREAD_DANGER:
		cue = DEEP[cue]
		level = mini(level, DEEP_MAX)
	play_cue(cue, level)

func _danger() -> int:
	# Screens can change before a run exists (menu, first boot), and node_at()
	# indexes straight into the map, so the empty case has to be caught here.
	if Run.map.is_empty():
		return 0
	var n: MapGen.MapNode = Run.node_at()
	return 0 if n == null else n.danger

## Start a cue, or move an already-running one to a new intensity. Changing
## intensity never restarts anything.
func play_cue(cue: StringName, level: int) -> void:
	if not _enabled or not CUES.has(cue):
		return
	_intensity = clampi(level, 0, CUES[cue].size() - 1)
	if _cue == cue:
		_apply_layers()
		return
	_cue = cue
	_ensure_loaded(cue)
	_start(cue)
	for c: StringName in _stems:
		_gain_target[c] = 1.0 if c == cue else 0.0
	_apply_layers()

func stop_music() -> void:
	for c: StringName in _stems:
		_gain_target[c] = 0.0
	_cue = &""

## Per-stem target volume: audible if the cue is running and the stem's rung
## has been reached, silent otherwise. Actual movement happens in _process.
func _apply_layers() -> void:
	for cue: StringName in _stems:
		var layers: Array = CUES[cue]
		for level in layers.size():
			for stem: StringName in layers[level]:
				var p: AudioStreamPlayer = _stems[cue][stem]
				p.set_meta(&"on", cue == _cue and level <= _intensity)

func _ensure_loaded(cue: StringName) -> void:
	if _stems.has(cue):
		return
	var players: Dictionary = {}
	for level in CUES[cue].size():
		for stem: StringName in CUES[cue][level]:
			var stream: AudioStream = load(MUSIC_DIR % [cue, stem])
			if stream == null:
				push_warning("Audio: missing music stem %s/%s" % [cue, stem])
				continue
			# The files are rendered as seamless loops; tell the stream to use
			# that rather than stopping at the end of the phrase.
			if stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = true
			var p := AudioStreamPlayer.new()
			p.stream = stream
			p.bus = &"Music"
			p.volume_db = OFF_DB
			p.set_meta(&"on", false)
			add_child(p)
			players[stem] = p
	_stems[cue] = players
	_gain[cue] = 0.0
	_gain_target[cue] = 0.0
	_running[cue] = false

## Every stem of a cue starts in the same frame, so they share a mix cycle and
## stay sample-locked. They are all exactly the same length, so they also loop
## together and cannot drift apart over a long session.
func _start(cue: StringName) -> void:
	if _running.get(cue, false):
		return
	_running[cue] = true
	for stem: StringName in _stems[cue]:
		(_stems[cue][stem] as AudioStreamPlayer).play()

## A cue that has finished fading out is left holding eight or nine Ogg streams
## decoding into silence. Stop it. Coming back restarts it from bar 1, which is
## what a crossfade between two different pieces wants anyway.
func _stop(cue: StringName) -> void:
	if not _running.get(cue, false):
		return
	_running[cue] = false
	for stem: StringName in _stems[cue]:
		(_stems[cue][stem] as AudioStreamPlayer).stop()

func _process(delta: float) -> void:
	if not _enabled or _stems.is_empty():
		return
	for cue: StringName in _stems:
		var g: float = _gain[cue]
		var t: float = _gain_target[cue]
		if not is_equal_approx(g, t):
			g = move_toward(g, t, delta / CROSSFADE)
			_gain[cue] = g
			if g <= 0.0:
				_stop(cue)
		if not _running.get(cue, false):
			continue
		for stem: StringName in _stems[cue]:
			var p: AudioStreamPlayer = _stems[cue][stem]
			var want: float = 0.0 if not p.get_meta(&"on", false) else 1.0
			var lv: float = move_toward(_stem_level(p), want, delta / FADE)
			p.set_meta(&"lv", lv)
			var v: float = lv * g
			p.volume_db = OFF_DB if v <= 0.001 else linear_to_db(v)

func _stem_level(p: AudioStreamPlayer) -> float:
	return float(p.get_meta(&"lv", 0.0))

# ---------------- sound effects ----------------

## pitch_var randomises playback rate a little, which is what keeps a click
## you hear four hundred times an hour from turning into a machine gun.
## limit_ms drops repeats inside a window, for signals that fire in bursts.
func play(name: StringName, pitch_var: float = 0.06, limit_ms: int = 0) -> void:
	if not _enabled:
		return
	var now := Time.get_ticks_msec()
	if limit_ms > 0 and now - int(_last.get(name, -limit_ms)) < limit_ms:
		return
	_last[name] = now
	var stream: AudioStream = _cache.get(name)
	if stream == null:
		stream = load(SFX_PATH % name)
		if stream == null:
			push_warning("Audio: missing sfx %s" % name)
			return
		_cache[name] = stream
	# Round-robin the pool. Fourteen voices is more than the game ever asks
	# for at once; stealing the oldest is the right failure if it ever does.
	var p := _sfx[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx.size()
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()

func click() -> void:   play(&"ui_click", 0.05)
func hover() -> void:   play(&"ui_hover", 0.09, 40)
func back() -> void:    play(&"ui_back", 0.03)
func confirm() -> void: play(&"ui_confirm", 0.02)
func denied() -> void:  play(&"ui_denied", 0.03)

# ---------------- signal handlers ----------------

## The thermal ruling, made audible: ballistics run cold, energy weapons run
## hot. A card that prints heat gets the bright ionised zap; a card that does
## not gets the dry mechanical crack. You hear what a build is made of.
func _on_card_played(c: CardData) -> void:
	play(&"card_play", 0.05)
	if c.damage > 0 or c.damage_equals_heat or c.heat_scale > 0:
		play(&"weapon_energy" if c.heat > 0 else &"weapon_ballistic", 0.07)
	elif c.vent > 0 or c.vent_all:
		play(&"vent", 0.05)
	elif c.block > 0 or c.armor > 0 or c.armor_from_heat:
		play(&"shield_block", 0.06)

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

func _on_damage(_amount: int, to_player: bool, _who: int) -> void:
	if to_player:
		play(&"impact_hull", 0.05)

func _on_combat_ended(result: StringName, _summary: String) -> void:
	match result:
		&"victory", &"won", &"pacified": play(&"victory", 0.0)
		&"fled": play(&"ui_tab", 0.03)
		_: pass          ## death is handled by run_ended, so it is not doubled

func _on_run_ended(won: bool, _reason: String) -> void:
	if won:
		play(&"victory", 0.0)
	else:
		# DREAD_NOTES §5: the mutation as a two-second sting — F to Gb on one
		# low bowed note. The semitone is the whole idea of the dread cue, so
		# dying sounds like the thing that has been following you all run.
		play(&"death_sting", 0.0)

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
