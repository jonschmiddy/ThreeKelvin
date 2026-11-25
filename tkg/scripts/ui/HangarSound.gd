class_name HangarSound
extends Node

## THE SHIP-SELECT HANGARS' SOUND (Jon, Nov 25: "K A, S A, O A + flicker 1 (filament tick) at +10 dB, buzz at
## +10 dB"): every stem started by its room's life on the room's own clock (`HangarCues`), panned by x, deeper
## sources quieter, wetter and darker, through one 5.5 s hall. No baked mix. Headless it decides and plays nothing.
## Why: docs/why/HangarSound.md#hangar-sound

const DIR := "res://assets/audio/hangar/%s.wav"
const DATA := "res://assets/audio/hangar/hangar.json"
## The cue map's 0 dB: the bed at -30 dB loudest second, where the mixer placed every layer from.
const REF := -30.0
const VOICES := 20
## The hall's sends (the mixer's concept A): heroes 0.7, the rest 0.35, + 0.35 a unit of depth; the bed 0.21, its air 0.175.
const WET_HERO := 0.7
const WET_BASE := 0.35
const AIR_DB := -4.0
## The hall, set against the mixer's own (`tools/dev/hangar_sound.py hall`): room size, damping, and its level.
## Why: docs/why/HangarSound.md#the-hall
const HALL_ROOM := 0.955
const HALL_DAMP := 0.5
const HALL_DB := -10.5
## Godot's compressor reads 2.08x the dB over its threshold, averaged sample by sample: this ratio is the mixer's
## 2:1, and its threshold sits this far over the mixer's RMS one (set by capture). Why: docs/why/HangarSound.md#the-bus
const COMP_RATIO := 1.3165
const COMP_DETECT := {&"korvan": 6.0, &"solari": 12.0, &"old": 2.0}
## A trim on every room after its capture was measured against its approved mix.
const LEVEL_TRIM := {&"korvan": -2.3, &"solari": -3.0, &"old": 1.5}
## The banner push (B2, every room) beside the rooms, as the page played it; the faders' defaults differ.
const BANNER := &"hangar_banner"

## Every start is kept in `starts` while this is on (the tests).
static var record := false
static var _shared: HangarSound = null
static var _data: Dictionary[String, Variant] = {}

var plan: HangarCues.Plan = null
var room: ShipRoom = null
var starts: Array[Dictionary] = []
var _yard: WeakRef = null
var _live := false
var _voices: Array[Voice] = []
var _t_prev := -1.0
var _streams: Dictionary[StringName, AudioStream] = {}
var _loops: Dictionary[StringName, Voice] = {}
var _bed_seg: PackedInt32Array = PackedInt32Array([-99, -99])
var _probe := -1.0
## How long the last room's plan took to work out, ms (printed by the test, never asserted).
var build_ms := 0.0


## One sound: its dry player on its own bus (pan, low-pass) and its send into the hall (the same, wet).
class Voice:
	var i := 0
	var dry: AudioStreamPlayer = null
	var wet: AudioStreamPlayer = null
	var cue: HangarCues.Cue = null
	var layer: HangarCues.Layer = null
	var id: StringName = &""
	var file: StringName = &""
	var busy := false
	var dry_db := 0.0
	var wet_db := -80.0
	## The fade (0..1) and where it is going, per second.
	var env := 0.0
	var rate := 0.0
	## A layer's level and a crew sound's allowance (0..1), as it is heard.
	var level := 1.0
	var allow := 1.0
	var allow_to := 1.0
	var t0 := 0.0
	var stop_at := INF
	var fade_out := 0.25
	var ends := INF
	var pitch := 1.0
	var pos0 := 0.0
	var lead := 0.0

	func heard() -> float:
		return env * level * allow


static func shared() -> HangarSound:
	if _shared == null or not is_instance_valid(_shared):
		_shared = HangarSound.new()
		_shared.name = "HangarSound"
		Audio.add_child(_shared)
	return _shared


static func data() -> Dictionary[String, Variant]:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		if d is Dictionary:
			_data.assign(d)
	return _data


static func file_info(f: StringName) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	var d: Variant = (data().get("files", {}) as Dictionary).get(String(f))
	if d is Dictionary:
		out.assign(d)
	return out


## A fixed coin in [0, 1) per key, so a room varies the same way every visit (the mixer's h01).
static func h01(key: String) -> float:
	return float(hash(key) & 0xFFFFFF) / 16777216.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_live = DisplayServer.get_name() != "headless" and not "sim" in OS.get_cmdline_user_args()
	for i in VOICES:
		var v := Voice.new()
		v.i = i
		if _live:
			v.dry = _player(_voice_bus("HangarDry%d" % i, &"Hangar"))
			v.wet = _player(_voice_bus("HangarWet%d" % i, &"HangarHall"))
		_voices.append(v)


func _player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


# ------------------------------------------------------------------ the buses (made once, kept, as YardSound's)
static func _bus(n: String, to: StringName) -> int:
	var idx := AudioServer.get_bus_index(n)
	if idx >= 0:
		return idx
	AudioServer.add_bus()
	idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, n)
	AudioServer.set_bus_send(idx, to)
	return idx


## The room's bus: the mixer's bus EQ, its gentle compression, and a true-peak ceiling, into Ambient.
static func _master_bus() -> int:
	var made := AudioServer.get_bus_index("Hangar") >= 0
	var idx := _bus("Hangar", &"Ambient")
	if made:
		return idx
	var eq := AudioEffectEQ21.new()
	var g: Array = data().get("eq21", [])
	for b in mini(g.size(), eq.get_band_count()):
		eq.set_band_gain_db(b, float(g[b]))
	AudioServer.add_bus_effect(idx, eq)
	var c := AudioEffectCompressor.new()
	c.ratio = COMP_RATIO
	c.attack_us = 40000.0
	c.release_ms = 600.0
	AudioServer.add_bus_effect(idx, c)
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -3.5
	AudioServer.add_bus_effect(idx, lim)
	# the hall: wet alone, its tail shelved 6 dB above 5 kHz
	var h := _bus("HangarHall", &"Hangar")
	var rv := AudioEffectReverb.new()
	rv.room_size = HALL_ROOM
	rv.damping = HALL_DAMP
	rv.spread = 1.0
	rv.hipass = 0.0
	rv.dry = 0.0
	rv.wet = 1.0
	rv.predelay_msec = 62.0
	rv.predelay_feedback = 0.0
	AudioServer.add_bus_effect(h, rv)
	var sh := AudioEffectHighShelfFilter.new()
	sh.cutoff_hz = 5000.0
	sh.gain = 0.5
	AudioServer.add_bus_effect(h, sh)
	AudioServer.set_bus_volume_db(h, HALL_DB)
	return idx


static func _voice_bus(n: String, to: StringName) -> StringName:
	_master_bus()
	var made := AudioServer.get_bus_index(n) >= 0
	var idx := _bus(n, to)
	if not made:
		AudioServer.add_bus_effect(idx, AudioEffectPanner.new())
		# the mixer's 2nd-order Butterworth run forward and back: two plain biquads (Godot's 24DB is four, a
		# far steeper slope that took 10 dB off 4-8 kHz). Why: docs/why/HangarSound.md#depth-low-pass
		for i in 2:
			var lp := AudioEffectLowPassFilter.new()
			lp.resonance = 0.7071
			lp.db = AudioEffectFilter.FILTER_6DB
			AudioServer.add_bus_effect(idx, lp)
	return StringName(n)


func _set_room_bus(id: StringName) -> void:
	if not _live:
		return
	var r: Dictionary = (data().get("rooms", {}) as Dictionary).get(String(id), {})
	var idx := _master_bus()
	AudioServer.set_bus_volume_db(idx, float(r.get("gain_db", -11.0)) + float(LEVEL_TRIM.get(id, 0.0)))
	var c := AudioServer.get_bus_effect(idx, 1) as AudioEffectCompressor
	if c != null:
		c.threshold = float(r.get("thr_rms_db", -23.0)) + float(COMP_DETECT.get(id, 2.0))


## Constant power (the mixer's) as Godot's balance panner takes it: (its pan, the dB to make up).
static func pan_for(x: float, k: float) -> Vector2:
	var p := clampf(x / 960.0 * 2.0 - 1.0, -1.0, 1.0) * k
	var th := (p + 1.0) * PI / 4.0
	var l := cos(th) * sqrt(2.0)
	var r := sin(th) * sqrt(2.0)
	return Vector2((r - l) / (r + l), linear_to_db((r + l) * 0.5))


func _route(v: Voice, x: float, k: float, dark: float) -> float:
	var pn := pan_for(x, k)
	if _live:
		for bus: StringName in [v.dry.bus, v.wet.bus]:
			var idx := AudioServer.get_bus_index(bus)
			(AudioServer.get_bus_effect(idx, 0) as AudioEffectPanner).pan = pn.x
			for e in [1, 2]:
				(AudioServer.get_bus_effect(idx, e) as AudioEffectFilter).cutoff_hz = 7000.0 - 5200.0 * dark
				AudioServer.set_bus_effect_enabled(idx, e, dark > 0.0)
	return pn.y


## dB the low-pass takes off the file at `dark` (the mixer normalised after its darkening; the game's file before).
static func dark_comp(f: StringName, dark: float) -> float:
	var lp: Array = file_info(f).get("lp", [])
	if lp.is_empty() or dark <= 0.0:
		return 0.0
	var u := clampf(dark, 0.0, 1.0) * 20.0
	var a := int(floorf(u))
	var b := mini(a + 1, lp.size() - 1)
	return lerpf(float(lp[a]), float(lp[b]), u - a)


# ------------------------------------------------------------------ the room shown
## The room on show, from its yard; null leaves.
func show_room(r: ShipRoom, yard: Control) -> void:
	if r == room and r != null:
		return
	hush(0.3)
	room = r
	_yard = weakref(yard) if yard != null else null
	var us := Time.get_ticks_usec()
	plan = HangarCues.plan_for(r) if r != null else null
	build_ms = (Time.get_ticks_usec() - us) / 1000.0
	_t_prev = -1.0
	_bed_seg = PackedInt32Array([-99, -99])
	if r != null:
		_set_room_bus(r.id)


func _shown() -> bool:
	if room == null or _yard == null:
		return false
	var y := _yard.get_ref() as Control
	return y != null and y.is_visible_in_tree()


## Everything out over `secs`; the next tick starts the room again from its clock.
func hush(secs: float = 0.3) -> void:
	for v in _voices:
		if v.busy:
			v.rate = -1.0 / maxf(0.01, secs)
			v.stop_at = -INF
	_loops.clear()
	_t_prev = -1.0


func _process(delta: float) -> void:
	if room != null and not _shown():
		hush(0.3)
		if _yard == null or _yard.get_ref() == null:
			room = null
			plan = null
	_fade(delta)


## Each frame after the room's tick (`YardFront._process`): what its life starts now, the beds, the layers.
func tick() -> void:
	if plan == null or not _shown():
		return
	var t := room.t
	if _probe >= 0.0:
		_probe_tick(t)
		return
	if _t_prev < 0.0:
		_t_prev = t - 1e-6
		_start_loops(t)
	_beds(t)
	_layers(t)
	_due(_t_prev, t)
	_crew(t)
	_step(t)
	_t_prev = t


# ------------------------------------------------------------------ voices
func _free_voice() -> Voice:
	for v in _voices:
		if not v.busy:
			return v
	# the quietest goes (never a bed)
	var best: Voice = null
	for v in _voices:
		if v.layer == null and v.id != &"bed" and (best == null or v.heard() < best.heard()):
			best = v
	return best


func _start(v: Voice, file: StringName, from: float, pitch: float, t: float) -> void:
	v.busy = true
	v.file = file
	v.t0 = t
	v.pos0 = from
	v.pitch = pitch
	v.stop_at = INF
	v.ends = INF
	v.allow = 1.0
	v.allow_to = 1.0
	v.level = 1.0
	if not _live:
		return
	var s := _stream(file)
	for p: AudioStreamPlayer in [v.dry, v.wet]:
		p.stream = s
		p.pitch_scale = pitch
		p.volume_db = -80.0
		if s != null:
			p.play(from)


func _stream(f: StringName) -> AudioStream:
	if not _streams.has(f):
		_streams[f] = load(DIR % f) as AudioStream
	return _streams[f]


func _stop(v: Voice) -> void:
	v.busy = false
	v.cue = null
	v.layer = null
	v.id = &""
	v.env = 0.0
	if _live:
		v.dry.stop()
		v.wet.stop()


## Fades, ends and levels: every frame, the room shown or not.
func _fade(delta: float) -> void:
	for v in _voices:
		if not v.busy:
			continue
		v.env = clampf(v.env + v.rate * delta, 0.0, 1.0)
		v.allow = move_toward(v.allow, v.allow_to, delta / 0.07)
		if v.rate < 0.0 and v.env <= 0.0:
			_stop(v)
			continue
		if _live:
			var g := linear_to_db(maxf(v.heard(), 1e-5))
			v.dry.volume_db = v.dry_db + g
			v.wet.volume_db = v.wet_db + g
			if not v.dry.playing and v.layer == null and v.id != &"bed" and v.id != &"air":
				_stop(v)


## On the room's clock: ends, cuts and span stops.
func _step(t: float) -> void:
	for v in _voices:
		if not v.busy:
			continue
		if t >= v.ends:
			_stop(v)
		elif t >= v.stop_at and v.rate >= 0.0:
			v.rate = -1.0 / v.fade_out


func _log(id: StringName, file: StringName, t: float, at: float, lead: float, x: float, gain: float) -> void:
	if record:
		starts.append({"id": id, "room": room.id, "t": t, "at": at, "lead": lead, "x": x, "gain": gain,
			"file": file, "frame": Engine.get_process_frames()})
	if Audio.taping:
		Audio.tape.append([file, GameClock.now_ms(), gain, 1.0, GameClock.now(), Engine.get_process_frames(), id, 0.0])


# ------------------------------------------------------------------ the cues
func _due(t0: float, t1: float) -> void:
	var L := plan.loop
	var n0 := floori(t0 / L) - 1
	for c in plan.cues:
		for n in range(n0, floori(t1 / L) + 2):
			if c.lap >= 0 and posmod(n, 2) != c.lap:
				continue
			var at := n * L + c.at
			if at - 1.0 > t1 or at + 1.0 < t0:
				continue
			var occ := _occurrence(c, n)
			var s := at - occ.w if c.kind == HangarCues.Kind.SHOT else at
			if s > t0 and s <= t1:
				_fire(c, at, occ, t1)


## (take, pitch, level dB, lead s) of a cue's n-th lap, by the mixer's fixed coins.
func _occurrence(c: HangarCues.Cue, n: int) -> Vector4:
	var k := n * c.per + c.n
	var key := "%s|%s|%d" % [plan.room, c.id, k]
	var take := posmod(k + int(h01("%s|%s" % [plan.room, c.id]) * 7.0), c.files.size())
	var spread := 0.03 if c.hero else 0.05
	var lvl := (h01(key + "|l") - 0.5) * 3.0
	if c.k >= 0:
		take = posmod(c.k + n, c.files.size())
		spread = 0.06
	var pitch := 1.0 + (h01(key + "|p") - 0.5) * spread
	var lead := 0.0
	if c.kind == HangarCues.Kind.SHOT:
		var fi := file_info(c.files[take])
		var sp := float(fi.get("onset", 0.0)) if c.sync == HangarCues.Sync.ONSET else float(fi.get("hit", 0.0))
		lead = (minf(sp, 0.12) if c.sync == HangarCues.Sync.HIT and sp > 0.15 else sp) / pitch
	return Vector4(take, pitch, lvl, lead)


func _fire(c: HangarCues.Cue, at: float, occ: Vector4, t: float) -> void:
	if c.prio > 0 and c.kind == HangarCues.Kind.SHOT and not _crew_room(c, t):
		if record:
			starts.append({"id": c.id, "room": room.id, "t": t, "at": at, "lead": occ.w, "x": c.x, "gain": c.gain,
				"file": c.files[int(occ.x)], "frame": Engine.get_process_frames(), "skipped": true})
		return
	var v := _free_voice()
	if v == null:
		return
	var file: StringName = c.files[int(occ.x)]
	var fi := file_info(file)
	var d := minf(HangarCues.depth_of(c.y), 1.4)
	var raw := c.k >= 0
	var dist := (-2.0 if c.hero else -7.0) * d
	var wet := (WET_HERO if c.hero else WET_BASE) + 0.35 * minf(d, 1.0)
	var dark := 0.0 if raw else minf(1.0, c.dark + 0.25 * minf(d, 1.0))
	var rel := c.gain + dist + occ.z
	var from := 0.0
	if c.kind == HangarCues.Kind.SHOT and c.sync == HangarCues.Sync.HIT and float(fi.get("hit", 0.0)) > 0.15:
		from = float(fi.get("hit", 0.0)) - 0.12
	elif c.kind == HangarCues.Kind.SPAN:
		from = h01("%s|%s|%f|o" % [plan.room, c.id, at]) * float(fi.get("len", 1.0)) * 0.9
	_start(v, file, from, occ.y, t)
	v.cue = c
	v.id = c.id
	v.lead = occ.w
	var pan_k := 0.3 if raw else (0.6 if c.hero else 0.75)
	var pan_db := _route(v, c.x, pan_k, dark)
	v.dry_db = rel + (REF - float(fi.get("loud", -20.0))) + dark_comp(file, dark) + pan_db
	v.wet_db = v.dry_db + linear_to_db(wet)
	if c.kind == HangarCues.Kind.SPAN:
		v.env = 0.0
		v.rate = 1.0 / 0.05
		v.stop_at = t + (c.end - c.at)
		v.fade_out = 0.25
	else:
		v.env = 0.0 if from > 0.0 else 1.0
		v.rate = 1.0 / 0.1
		v.ends = t + (float(fi.get("len", 1.0)) - from) / occ.y + 0.05
		if c.cut > 0.0:
			v.stop_at = t + (c.cut + 0.4 - 0.6) / occ.y
			v.fade_out = 0.6
	_log(c.id, file, t, at, occ.w, c.x, rel)


# ------------------------------------------------------------------ crew: at most two at once, by priority
## The crew cues heard now, best first (priority, then id), with each one's voice.
func _crew_live(t: float) -> Array[Voice]:
	var live: Array[Voice] = []
	for v in _voices:
		if not v.busy or v.cue == null or v.cue.prio <= 0 or v.rate < 0.0:
			continue
		if v.cue.kind == HangarCues.Kind.SPAN or t <= v.t0 + v.cue.dur:
			live.append(v)
	live.sort_custom(func(a: Voice, b: Voice) -> bool:
		return a.cue.prio > b.cue.prio or (a.cue.prio == b.cue.prio and String(a.cue.id) < String(b.cue.id)))
	return live


func _crew(t: float) -> void:
	var live := _crew_live(t)
	for i in live.size():
		live[i].allow_to = 1.0 if i < 2 else 0.0


## May a crew shot sound now: fewer than two better crew sounds playing.
func _crew_room(c: HangarCues.Cue, t: float) -> bool:
	var better := 0
	for v in _crew_live(t):
		if v.cue.prio > c.prio or (v.cue.prio == c.prio and String(v.cue.id) < String(c.id)):
			better += 1
	return better < 2


## How many crew sounds are let through now (the two-at-once rule): for the tests.
func crew_allowed() -> int:
	var n := 0
	for v in _crew_live(_t_prev):
		if v.allow_to > 0.5:
			n += 1
	return n


# ------------------------------------------------------------------ the beds and layers
func _start_loops(t: float) -> void:
	var air := _free_voice()
	if air != null:
		_start(air, plan.air, fposmod(t, float(file_info(plan.air).get("len", 30.0))), 1.0, t)
		air.id = &"air"
		air.env = 0.0
		air.rate = 1.0 / 1.2
		_route(air, 480.0, 0.0, 0.0)
		air.dry_db = AIR_DB + REF - float(file_info(plan.air).get("loud", -20.0))
		air.wet_db = air.dry_db + linear_to_db(WET_BASE * 0.5)
		_loops[&"air"] = air
	for ly in plan.layers:
		var v := _free_voice()
		if v == null:
			continue
		var ln := float(file_info(ly.file).get("len", 10.0))
		_start(v, ly.file, fposmod(t, ln) if ly.synced else h01(plan.room + String(ly.id)) * ln, 1.0, t)
		v.layer = ly
		v.id = ly.id
		v.env = 0.0
		v.rate = 1.0 / (0.02 if ly.synced else 1.2)
		_loops[ly.id] = v
		if ly.synced:
			_log(ly.id, ly.file, t, t, 0.0, ly.x, ly.gain)


func _layers(t: float) -> void:
	for ly in plan.layers:
		var v: Voice = _loops.get(ly.id)
		if v == null:
			continue
		v.level = float(ly.level.call(t)) if ly.level.is_valid() else 1.0
		var x := float(ly.at_x.call(t)) if ly.at_x.is_valid() else ly.x
		var pan_db := _route(v, x, ly.pan_k, ly.dark)
		v.dry_db = ly.gain + REF - float(file_info(ly.file).get("loud", -20.0)) + dark_comp(ly.file, ly.dark) + pan_db
		v.wet_db = v.dry_db + linear_to_db(maxf(ly.wet, 1e-4))
		if ly.synced and _live and v.dry.playing:
			var want := fposmod(t, float(file_info(ly.file).get("len", 30.0)))
			if absf(v.dry.get_playback_position() - want) > 0.1 and absf(v.dry.get_playback_position() - want) < 29.0:
				v.dry.seek(want)
				v.wet.seek(want)


## The bed: its two takes alternating every `seg` s with 3 s equal-power crossfades, drifting slowly (the mixer's).
func _beds(t: float) -> void:
	var seg := plan.seg
	var xf := minf(3.0, seg / 3.0)
	var period := plan.loop * (2.0 if plan.loop >= 30.0 else 3.0)
	var drift := 1.0 + 0.12 * sin(TAU * t / period + h01(plan.room + "|drift") * TAU)
	var j := floori((t + xf * 0.5) / seg)
	for s: int in [j - 1, j]:
		var w := posmod(s, 2)
		var a := s * seg - xf * 0.5
		var b := (s + 1) * seg + xf * 0.5
		if t < a or t >= b:
			continue
		var key := StringName("bed%d" % w)
		var v: Voice = _loops.get(key)
		var f: StringName = plan.beds[w % plan.beds.size()]
		var ln := float(file_info(f).get("len", seg))
		if v == null or _bed_seg[w] != s:
			if v == null:
				v = _free_voice()
				if v == null:
					continue
				_loops[key] = v
			_start(v, f, fposmod(h01("%s|bedoff|%d" % [plan.room, s]) * ln + (t - a), ln), 1.0, t)
			v.id = &"bed"
			v.rate = 0.0
			_route(v, 480.0, 0.0, 0.1)
			_bed_seg[w] = s
		var r_in := clampf((t - a) / xf, 0.0, 1.0)
		var r_out := clampf((b - t) / xf, 0.0, 1.0)
		v.env = sin(r_in * PI / 2.0) * sin(r_out * PI / 2.0) if t - a < xf or b - t < xf else 1.0
		v.level = drift
		v.dry_db = REF - float(file_info(f).get("loud", -20.0)) + dark_comp(f, 0.1)
		v.wet_db = v.dry_db + linear_to_db(WET_BASE * 0.6)


# ------------------------------------------------------------------ the hall probe
## The room hushed, then a crate's thud dry alone at 2 s and into the hall alone at 8 s, for a capture
## (`-- sheet=ShipRoomShot hallprobe=1 film=24`) that `tools/dev/hangar_sound.py hall` sets the hall from.
func probe() -> void:
	hush(0.01)
	_probe = room.t if room != null else 0.0
	_t_prev = 0.0


func _probe_tick(t: float) -> void:
	var u := t - _probe
	for at: float in [2.0, 8.0]:
		if _t_prev < at and u >= at:
			var v := _free_voice()
			_start(v, &"crate_1", 0.0, 1.0, t)
			v.id = &"probe"
			v.env = 1.0
			v.ends = t + 2.0
			_route(v, 480.0, 0.0, 0.0)
			var dry := REF - float(file_info(&"crate_1").get("loud", -20.0))
			v.dry_db = dry if at < 5.0 else -200.0
			v.wet_db = dry if at > 5.0 else -200.0
	_step(t)
	_t_prev = u


# ------------------------------------------------------------------ the banner push
## A banner shoved by the pointer (`YardClothAir`): B2 at the page's level beside the rooms, a soft shove quieter.
## Why: docs/why/HangarSound.md#banner-push
static func banner_push(kick: float) -> void:
	var fi := file_info(BANNER)
	var page := float(fi.get("page_loud", -32.0)) - float(fi.get("loud", -20.0))
	var faders := linear_to_db(0.7) - linear_to_db(0.9)
	Audio.play(BANNER, 0.03, 90, page + faders + clampf(10.0 * log(kick / 2.4) / log(10.0), -4.0, 2.0))
