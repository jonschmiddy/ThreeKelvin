class_name StationSound
extends Node

## THE STATION DECKS' SOUND (Jon, Nov 26: Promenade B "Lunch arcade" / unclaimed C "Closing time", Shipyard B "Clean
## factory" / unclaimed A "Empty hangar", Exchange B "Server room", Hiring Board B "Strip lights"): each deck its own
## room, the hangars' way: a bed, one mover, rare events each started on a frame you can see, one hall
## set in code. The plan is `station.json` (`tools/dev/station_sound.py`), read once at docking. The Lab keeps its own.
## Why: docs/why/StationSound.md#station-sound

const DIR := "res://assets/audio/station/%s.wav"
const DATA := "res://assets/audio/station/station.json"
## The PA's lines: one table (each line's speaker, text, `when`, tiers, file, role; the chime and the bang).
## Why: docs/why/StationSound.md#the-pa
const PA_TABLE := "res://assets/audio/station/pa.json"
## The plan's 0 dB: the bed's loudest second, where the mixer placed every layer from.
const REF := -30.0
const VOICES := 18
## The decks by `StationScreen` page.
const DECK_OF := {&"stock": &"prom", &"services": &"yard", &"hold": &"exch", &"work": &"board", &"bench": &"lab"}
const TIERS: Array[String] = ["unclaimed", "outpost", "settlement", "city", "capital"]
## The decks' room for `Audio.room`: no tone of its own (each deck plays its own; the Lab's bed is `LabScene`'s).
const DECKS_ROOM := &"station"
## The bus (the mixer's 2:1 as Godot's compressor reads it, as the hangars'), and a trim per room by capture, so the
## bus sits where its page mix does (a capture at the default faders reads 4 dB under). Why: docs/why/StationSound.md#levels
const COMP_RATIO := 1.3165
const COMP_DETECT := 8.0
const LEVEL_TRIM := {
	&"prom:unclaimed": -5.1, &"prom:outpost": -5.1, &"prom:settlement": -3.9, &"prom:city": -3.9, &"prom:capital": -3.9,
	&"yard:unclaimed": -4.4, &"yard:outpost": -4.4, &"yard:settlement": -3.6, &"yard:city": -3.6, &"yard:capital": -3.6,
	&"exch:unclaimed": -3.6, &"exch:outpost": -3.6, &"exch:settlement": -3.6, &"exch:city": -3.6, &"exch:capital": -3.6,
	&"board:unclaimed": -3.8, &"board:outpost": -3.8, &"board:settlement": -3.8, &"board:city": -3.8, &"board:capital": -3.8,
}
## The PA (Jon's Nov 26 script): after a fresh docking a dock line 5-8 s after the first deck shows (once the dock's
## clunk and the deck's power-on are past); where no dock line is read, a line 15-25 s in; then one 60-120 s after
## one ends, at random; never in a ride.
const PA_DOCK := Vector2(5.0, 8.0)
const PA_FIRST := Vector2(15.0, 25.0)
const PA_GAP := Vector2(60.0, 120.0)
## A follow-up (a row with `after`): about one lead in three, 5-10 s after the lead ends; dropped if a ride holds it 15 s.
const PA_AFTER := Vector2(5.0, 10.0)
const PA_AFTER_P := 1.0 / 3.0
const PA_AFTER_LATE := 15.0
## reactor_1 ("That bang was the reactor venting") comes this long after its bang starts (then its chime).
const BANG_LEAD := 1.2
## The unclaimed tape: dips (start, end, depth, as parts of the line), its wow (the mixer's); it cuts where its row's
## `cut` says the written line stops.
const TAPE_DIPS := [[0.38, 0.47, 0.08], [0.61, 0.645, 0.25]]
## The yard's rare events with no sound (Jon, Nov 25, 4B): the jokes. Every other rare event is listed with its sound.
const JOKES: Array[String] = ["E6", "E11", "E12", "E13", "E18", "E20"]
## The screen's middle, where the mixer's ships and flyers were "passing", and its width for the pan.
const MID_X := 480.0
const YARD_MID := 383.0

## Every start is kept in `starts` while this is on (the tests).
static var record := false
static var _shared: StationSound = null
static var _data: Dictionary[String, Variant] = {}
static var _pa_rows: Array[Dictionary] = []
static var _pa_ids: Dictionary[String, Dictionary] = {}
static var _pa_extra: Dictionary[String, Dictionary] = {}
## The PA's dealing lasts the run (static: across dockings and decks), so the whole pool is heard before any line
## twice (Jon, Nov 26: "really random"): the bag of line ids, the dock lines' own bag, the last line read.
static var pa_rng := RandomNumberGenerator.new()
static var _pa_bag: Array[String] = []
static var _pa_dock_bag: Array[String] = []
static var _pa_last_when := ""
static var _pa_last_id := ""
## How long each deck took to open (ms), by deck: printed by the films and the test.
static var open_ms: Dictionary[StringName, float] = {}

var deck: StringName = &""
var tier := ""
var plan: Dictionary[String, Variant] = {}
var starts: Array[Dictionary] = []
## Seconds on this deck's sound clock (process time, so a film runs true).
var t := 0.0
var _screen: WeakRef = null
var _live := false
var _quiet := false
var _voices: Array[Voice] = []
var _streams: Dictionary[StringName, AudioStream] = {}
var _asked: Dictionary[String, bool] = {}
var _loops: Dictionary[StringName, Voice] = {}
var _bed_seg: PackedInt32Array = PackedInt32Array([-99, -99])
var _riding := false
var _n: Dictionary[StringName, int] = {}
## What each deck's scene showed last frame (walkers' frames, the lamp, the yard's events).
var _seen: Dictionary[String, Variant] = {}
var _pa: Voice = null
var _pa_next := INF
var _pa_len := 0.0
var _pa_t0 := 0.0
var _pa_tape := false
var _pa_cut := false
var _pa_cut_at := INF
## The line being announced (its bang or chime playing) and when its next step is due.
var _pa_line: Dictionary = {}
var _pa_line_at := INF
var _pa_chimed := false
## Follow-ups due ({row, at}), the lines heard this docking (lift_2 waits for lift_1), and a fresh docking's dock line.
var _pa_after: Array[Dictionary] = []
var _pa_heard: Dictionary[String, bool] = {}
var _pa_fresh := false
var _pa_dock_due := false
var _yt := -1.0
## When the deck on show came up (its bed comes in over half a second from then).
var _shown_at := 0.0


## One sound: its dry player on its own bus (pan, low-pass) and its send into the hall.
class Voice:
	var i := 0
	var dry: AudioStreamPlayer = null
	var wet: AudioStreamPlayer = null
	## Its own buses (a PA line borrows a speaker's for its length).
	var dry_bus: StringName = &""
	var wet_bus: StringName = &""
	var id: StringName = &""
	var file: StringName = &""
	var busy := false
	var loop := false
	var dry_db := 0.0
	var wet_db := -80.0
	var env := 0.0
	var rate := 0.0
	var level := 1.0
	var t0 := 0.0
	var stop_at := INF
	var fade_out := 0.25
	var ends := INF

	func heard() -> float:
		return env * level


static func shared() -> StationSound:
	if _shared == null or not is_instance_valid(_shared):
		_shared = StationSound.new()
		_shared.name = "StationSound"
		Audio.add_child(_shared)
	return _shared


static func data() -> Dictionary[String, Variant]:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		if d is Dictionary:
			_data.assign(d)
	return _data


static func pa_rows() -> Array[Dictionary]:
	if _pa_rows.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PA_TABLE))
		if d is Dictionary:
			for r: Variant in (d as Dictionary).get("lines", []):
				if r is Dictionary:
					_pa_rows.append(r as Dictionary)
	return _pa_rows


static func file_info(f: StringName) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	var d: Variant = (data().get("files", {}) as Dictionary).get(String(f))
	if d is Dictionary:
		out.assign(d)
	return out


## A deck's plan at a tier ({} for the Lab and anything unplanned).
static func plan_of(dk: StringName, tr: String) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	var r: Variant = (data().get("rooms", {}) as Dictionary).get("%s:%s" % [dk, tr])
	if r is Dictionary:
		out.assign(r)
		var idea: Variant = (out.get("pa_ideas", {}) as Dictionary).get(pa_pick())
		if idea is Dictionary:
			out["pa"] = idea
	return out


## The PA idea on trial (station.json `pa_pick`, or `pa_pick=X` on the command line for the films); "" for the room's
## own `pa`. Why: docs/why/StationSound.md#the-pa
static func pa_pick() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("pa_pick="):
			return a.trim_prefix("pa_pick=")
	return String(data().get("pa_pick", ""))


## Every file a plan plays.
static func files_of(p: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for f: Variant in p.get("beds", []):
		out.append(StringName(str(f)))
	for ly: Variant in p.get("layers", []):
		for f: Variant in (ly as Dictionary).get("files", []):
			out.append(StringName(str(f)))
	for k: Variant in (p.get("map", {}) as Dictionary):
		for f: Variant in ((p["map"] as Dictionary)[k] as Dictionary).get("files", []):
			out.append(StringName(str(f)))
	if (p.get("pa", {}) as Dictionary).get("speaker", "").begins_with("tape"):
		out.append(&"pa_tape_clunk")
	return out


static func h01(key: String) -> float:
	return float(hash(key) & 0xFFFFFF) / 16777216.0


static func tier_of(dev: int) -> String:
	return TIERS[clampi(dev, 0, TIERS.size() - 1)]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_quiet = "sim" in OS.get_cmdline_user_args()
	_live = DisplayServer.get_name() != "headless" and not _quiet
	for i in VOICES:
		var v := Voice.new()
		v.i = i
		if _live:
			v.dry_bus = StationBus.voice("StationDry%d" % i, &"Station")
			v.wet_bus = StationBus.voice("StationWet%d" % i, &"StationHall")
			v.dry = _player(v.dry_bus)
			v.wet = _player(v.wet_bus)
		_voices.append(v)


func _player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


# ------------------------------------------------------------------ docking
## A station's screen is up (`StationScreen.setup`): its plan and every file its tier plays are asked for now, on
## threads, so no deck hitches the first time it opens. `fresh`: a new docking (the PA starts over).
func dock(_scr: Control, fresh: bool) -> void:
	var here: MapGen.MapNode = Run.node_at() if not Run.map.is_empty() else null
	tier = tier_of(int(here.development) if here != null else MapGen.Development.SETTLEMENT)
	var us := Time.get_ticks_usec()
	data()
	pa_rows()
	if _live:
		for dk: StringName in [&"prom", &"yard", &"exch", &"board", &"lab"]:
			for f in files_of(plan_of(dk, tier)):
				_ask(DIR % f)
		for f in _pa_files(tier):
			_ask(f)
	open_ms[&"dock"] = (Time.get_ticks_usec() - us) / 1000.0
	if fresh:
		# (the bags carry on: a new docking hears the rest of the pool)
		_pa_next = INF
		_pa_heard.clear()
		_pa_after.clear()
		_pa_fresh = true


func _ask(path: String) -> void:
	if path == "" or _asked.has(path) or not ResourceLoader.exists(path):
		return
	_asked[path] = true
	ResourceLoader.load_threaded_request(path)


func _stream(path: String) -> AudioStream:
	var key := StringName(path)
	if not _streams.has(key):
		var s: AudioStream = null
		if _asked.has(path):
			s = ResourceLoader.load_threaded_get(path) as AudioStream
		if s == null and ResourceLoader.exists(path):
			s = load(path) as AudioStream
		if s is AudioStreamWAV and (s as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED and _is_loop(path):
			Audio.loop_whole(s as AudioStreamWAV)
		_streams[key] = s
	return _streams[key]


func _is_loop(path: String) -> bool:
	return bool(file_info(StringName(path.get_file().get_basename())).get("loop", false))


## The deck on show: `id` a StationScreen page, or &"" for none.
func show_deck(id: StringName) -> void:
	var dk: StringName = DECK_OF.get(id, &"")
	if dk == deck:
		return
	var us := Time.get_ticks_usec()
	hush(0.3)
	deck = dk
	_shown_at = t
	plan = plan_of(dk, tier) if dk != &"" else {}
	_bed_seg = PackedInt32Array([-99, -99])
	_seen.clear()
	_loops.clear()
	if dk != &"":
		Audio.room(DECKS_ROOM, 0.4)
	if not plan.is_empty():
		if _pa_next == INF:
			_pa_dock_due = _pa_fresh and pa_rows().any(func(r: Dictionary) -> bool:
				return pa_fits(r, "dock", tier, dk, {}))
			_pa_fresh = false
			var w := PA_DOCK if _pa_dock_due else PA_FIRST
			_pa_next = t + pa_rng.randf_range(w.x, w.y)
		StationBus.set_room(plan, _live)
		if _live:
			for f in files_of(plan):
				_stream(DIR % f)
	if dk != &"" and not open_ms.has(dk):
		open_ms[dk] = (Time.get_ticks_usec() - us) / 1000.0


## Everything out over `secs`.
func hush(secs: float = 0.3) -> void:
	for v in _voices:
		if v.busy:
			v.rate = -1.0 / maxf(0.01, secs)
			v.stop_at = -INF
	_loops.clear()
	if _pa_line_at < INF:
		_pa_cancel()


## Leaving the station: silent, and the next docking's PA starts over.
func leave() -> void:
	hush(0.3)
	deck = &""
	plan = {}
	_pa_next = INF
	_pa_line = {}
	_pa_line_at = INF
	_pa_after.clear()
	_screen = null


func _process(delta: float) -> void:
	if deck != &"" and (_screen == null or _screen.get_ref() == null \
			or not (_screen.get_ref() as Control).is_visible_in_tree()):
		leave()
	_fade(delta)


# ------------------------------------------------------------------ each frame, from the screen
## One frame of the deck on show (`StationScreen._process`): the deck and the ride, the beds, the layers, the events.
func tick(scr: StationScreen, delta: float) -> void:
	if _quiet:
		return
	if _screen == null or _screen.get_ref() != scr:
		# (a new screen: its deck shown afresh, its room tone asked for again)
		_screen = weakref(scr)
		hush(0.3)
		deck = &""
	t += delta
	show_deck(scr.deck_shown())
	var riding := scr.deck_changing()
	if riding and not _riding:
		_ride_hush()
	_riding = riding
	if plan.is_empty():
		return
	_beds()
	_layers(scr)
	if not riding:
		match deck:
			&"prom":
				_promenade(scr.deck_room(&"stock") as ShopScene)
			&"exch":
				_exchange(scr.deck_room(&"hold") as ExchangeScene)
	_pa_tick()
	_step()


## A ride starting: every event out (beds and layers carry on); the PA's line too.
func _ride_hush() -> void:
	for v in _voices:
		if v.busy and v.id != &"bed" and not _loops.values().has(v):
			v.rate = -1.0 / 0.2
			v.stop_at = -INF


# ------------------------------------------------------------------ voices
func _free_voice() -> Voice:
	for v in _voices:
		if not v.busy:
			return v
	var best: Voice = null
	for v in _voices:
		if v.id != &"bed" and not _loops.values().has(v) and (best == null or v.heard() < best.heard()):
			best = v
	return best


func _start(v: Voice, path: String, from: float, pitch: float) -> void:
	v.busy = true
	v.file = StringName(path.get_file().get_basename())
	v.t0 = t
	v.stop_at = INF
	v.ends = INF
	v.level = 1.0
	if not _live:
		return
	var s := _stream(path)
	v.dry.bus = v.dry_bus
	v.wet.bus = v.wet_bus
	for p: AudioStreamPlayer in [v.dry, v.wet]:
		p.stream = s
		p.pitch_scale = pitch
		p.volume_db = -80.0
		if s != null:
			p.play(from)


func _stop(v: Voice) -> void:
	v.busy = false
	v.id = &""
	v.env = 0.0
	if _live:
		v.dry.stop()
		v.wet.stop()


func _fade(delta: float) -> void:
	for v in _voices:
		if not v.busy:
			continue
		v.env = clampf(v.env + v.rate * delta, 0.0, 1.0)
		if v.rate < 0.0 and v.env <= 0.0:
			_stop(v)
			continue
		if _live:
			var g := linear_to_db(maxf(v.heard(), 1e-5))
			v.dry.volume_db = v.dry_db + g
			v.wet.volume_db = v.wet_db + g
			if not v.dry.playing and not v.loop:
				_stop(v)


func _step() -> void:
	for v in _voices:
		if not v.busy:
			continue
		if t >= v.ends:
			_stop(v)
		elif t >= v.stop_at and v.rate >= 0.0:
			v.rate = -1.0 / v.fade_out


func _route(v: Voice, x: float, k: float, dark: float) -> float:
	var pn := HangarSound.pan_for(x, k)
	if _live:
		StationBus.route(v.dry.bus, pn.x, dark)
		StationBus.route(v.wet.bus, pn.x, dark)
	return pn.y


static func dark_comp(f: StringName, dark: float) -> float:
	return _lp_at(file_info(f).get("lp", []), dark)


## dB back for the low-pass at `dark`, from a file's 21-step loss (`lp`).
static func _lp_at(lp: Array, dark: float) -> float:
	if lp.is_empty() or dark <= 0.0:
		return 0.0
	var u := clampf(dark, 0.0, 1.0) * 20.0
	var a := int(floorf(u))
	var b := mini(a + 1, lp.size() - 1)
	return lerpf(float(lp[a]), float(lp[b]), u - a)


## A room's crispness: a level of the hangars' (`HangarSound.CRISP`; the yard's is B2), or none.
static func crisp_of(p: Dictionary) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	var d: Variant = HangarSound.CRISP.get(StringName(str(p.get("crisp", ""))))
	if d is Dictionary:
		for k: Variant in d:
			out[str(k)] = (d as Dictionary)[k]
	return out


## A darkness at this room's crispness (B2 lifts its low-passes).
func dk(dark: float) -> float:
	return dark * float(crisp_of(plan).get("dark_k", 1.0))


func _log(id: StringName, file: StringName, x: float, gain: float, extra: Dictionary = {}) -> void:
	if record:
		var row: Dictionary = {"id": id, "deck": deck, "tier": tier, "t": t, "x": x, "gain": gain, "file": file,
			"riding": _riding, "frame": Engine.get_process_frames()}
		row.merge(extra)
		starts.append(row)
	if Audio.taping:
		Audio.tape.append([file, GameClock.now_ms(), gain, 1.0, GameClock.now(), Engine.get_process_frames(), id, 0.0])


# ------------------------------------------------------------------ the bed and the layers
## The bed: its two takes alternating every 15 s with 2.5 s equal-power crossfades, each piece from its own fixed
## place, drifting +-10 % over a minute (the mixer's `bed`).
func _beds() -> void:
	var beds: Array = plan.get("beds", [])
	if beds.is_empty():
		return
	var seg := 15.0
	var xf := 2.5
	var drift := 1.0 + 0.1 * sin(TAU * t / 60.0 + h01(deck + "|drift") * TAU)
	var j := floori((t + xf * 0.5) / seg)
	var dark := dk(float(plan.get("bed_dark", 0.0)))
	for w in 2:
		var idle: Voice = _loops.get(StringName("bed%d" % w))
		if idle != null:
			idle.env = 0.0
	for s: int in [j - 1, j]:
		var w := posmod(s, 2)
		var a := s * seg - xf * 0.5
		var b := (s + 1) * seg + xf * 0.5
		if t < a or t >= b:
			continue
		var key := StringName("bed%d" % w)
		var v: Voice = _loops.get(key)
		var f := StringName(str(beds[w % beds.size()]))
		var ln := float(file_info(f).get("len", seg))
		if v == null or _bed_seg[w] != s:
			if v == null:
				v = _free_voice()
				if v == null:
					continue
				_loops[key] = v
			var off := fposmod(h01("%s|bedoff|%d" % [deck, s]) * maxf(1.0, ln - seg - xf) + (t - a), ln)
			_start(v, DIR % f, off, 1.0)
			v.id = &"bed"
			v.loop = true
			v.rate = 0.0
			_route(v, MID_X, 0.0, dark)
			_bed_seg[w] = s
			_log(&"bed", f, MID_X, 0.0)
		var r_in := clampf((t - a) / xf, 0.0, 1.0)
		var r_out := clampf((b - t) / xf, 0.0, 1.0)
		v.env = sin(r_in * PI / 2.0) * sin(r_out * PI / 2.0)
		v.level = drift * clampf((t - _shown_at) / 0.5, 0.0, 1.0)
		v.dry_db = REF + float(plan.get("bed_db", 0.0)) - float(file_info(f).get("loud", -20.0)) + dark_comp(f, dark)
		v.wet_db = v.dry_db + linear_to_db(float(plan.get("wet_base", 0.2)) * 0.6)


## The station behind a closed door (the Board), and the movers that follow the picture: the forklift, the tube.
func _layers(scr: StationScreen) -> void:
	for ly: Variant in plan.get("layers", []):
		var d := ly as Dictionary
		var f := StringName(str((d.get("files", []) as Array)[0]))
		var v := _loop(StringName("layer:" + str(d.get("id", ""))), f, MID_X, 0.0)
		if v != null:
			v.dry_db = REF + float(plan.get("ref_db", 0.0)) + float(d.get("db", 0.0)) - float(file_info(f).get("loud", -20.0))
			v.wet_db = v.dry_db + linear_to_db(maxf(float(d.get("wet", 0.0)), 1e-4))
	match deck:
		&"board":
			var lamp := scr.deck_room(&"work") as BoardLamp
			_curve(&"tube", lamp.level() if lamp != null else 0.0, MID_X)
		&"yard":
			_fork()


## A steady loop under the room (started once, faded in over 1.2 s); null when no voice is free.
func _loop(key: StringName, f: StringName, x: float, dark: float) -> Voice:
	var v: Voice = _loops.get(key)
	if v == null:
		v = _free_voice()
		if v == null:
			return null
		_start(v, DIR % f, h01(String(key) + deck) * float(file_info(f).get("len", 8.0)), 1.0)
		v.id = key
		v.loop = true
		v.env = 0.0
		v.rate = 1.0 / 1.2
		_loops[key] = v
		_route(v, x, 0.0, dark)
		_log(key, f, x, 0.0)
	return v


## A loop whose level (0..1) and pan follow the picture each frame (the mixer's "curve").
func _curve(cls: StringName, g: float, x: float) -> void:
	var r: Dictionary = (plan.get("map", {}) as Dictionary).get(String(cls), {})
	if r.is_empty():
		return
	var f := StringName(str((r.get("files", []) as Array)[0]))
	var dark := dk(float(r.get("dark", 0.0)))
	var v := _loop(StringName("curve:" + String(cls)), f, x, dark)
	if v == null:
		return
	v.rate = 1.0 / 0.05
	v.level = clampf(g, 0.0, 1.5)
	var pan_db := _route(v, x, float(r.get("pan", 0.6)), dark)
	v.dry_db = REF + float(r.get("db", 0.0)) - float(file_info(f).get("loud", -20.0)) + dark_comp(f, dark) + pan_db
	v.wet_db = v.dry_db + linear_to_db(maxf(float(r.get("wet", plan.get("wet_base", 0.2))), 1e-4))


# ------------------------------------------------------------------ shots
## A rare event or a step: its take, pitch and level by a fixed hash of (deck, event, occurrence), placed so its
## first sound (onset) or its contact (hit) lands `late` s from now (the mixer's `sync_point`, `lead`).
func shot(cls: StringName, x: float, depth: float = 0.0, late: float = 0.0) -> void:
	var r: Dictionary = (plan.get("map", {}) as Dictionary).get(String(cls), {})
	if r.is_empty() or _riding:
		return
	var files: Array = r.get("files", [])
	var k: int = _n.get(cls, 0)
	_n[cls] = k + 1
	var key := "%s|%s|%d" % [deck, cls, k]
	var pick := int(h01(key + "|f") * 997.0) % files.size() if bool(r.get("rand", false)) else k % files.size()
	var f := StringName(str(files[pick]))
	var fi := file_info(f)
	var pitch := 1.0 + (h01(key + "|p") - 0.5) * float(r.get("pvar", 0.06))
	var lvl := (h01(key + "|l") - 0.5) * float(r.get("lvar", 3.0))
	var rel := float(r.get("db", 0.0)) + lvl - 6.0 * depth
	var dark := dk(minf(1.0, float(r.get("dark", 0.0)) + 0.3 * depth))
	var wet := float(r.get("wet", plan.get("wet_base", 0.2))) + 0.3 * depth
	var from := 0.0
	var hit := float(fi.get("hit", 0.0))
	if String(r.get("sync", "onset")) == "hit" and hit > 0.15:
		from = maxf(0.0, hit - maxf(late, 0.05) * pitch)
	var v := _free_voice()
	if v == null:
		return
	_start(v, DIR % f, from, pitch)
	v.id = cls
	v.loop = false
	v.env = 0.0 if from > 0.0 else 1.0
	v.rate = 1.0 / 0.08
	var trim := float(r.get("trim", 0.0))
	var ln := float(fi.get("len", 1.0)) - from
	v.ends = t + (minf(ln, trim) if trim > 0.0 else ln) / pitch + 0.05
	if trim > 0.0:
		v.stop_at = t + maxf(0.0, trim - 0.15) / pitch
		v.fade_out = 0.15
	var pan_db := _route(v, x, float(r.get("pan", 0.7)), dark)
	v.dry_db = rel + REF - float(fi.get("loud", -20.0)) + dark_comp(f, dark) + pan_db
	v.wet_db = v.dry_db + linear_to_db(wet)
	_log(cls, f, x, rel, {"late": late, "from": from})


## How long before its action a shot must start: its lead, and its first sound or contact, at its pitch (s).
func lead_of(cls: StringName) -> float:
	var r: Dictionary = (plan.get("map", {}) as Dictionary).get(String(cls), {})
	if r.is_empty():
		return 0.0
	var fi := file_info(StringName(str((r.get("files", [""]) as Array)[0])))
	var sp := minf(float(fi.get("hit", 0.0)), 0.1) if String(r.get("sync", "onset")) == "hit" \
		else float(fi.get("onset", 0.0))
	return float(r.get("lead", 0.0)) + sp


## A span: a loop from a fixed place in it while its action shows (the welder's arc), faded in and out.
func span(cls: StringName, on: bool, x: float) -> void:
	var r: Dictionary = (plan.get("map", {}) as Dictionary).get(String(cls), {})
	if r.is_empty():
		return
	var key := StringName("span:" + String(cls))
	var v: Voice = _loops.get(key)
	if not on or _riding:
		if v != null:
			v.rate = -1.0 / maxf(0.02, float(r.get("fout", 0.2)))
			v.stop_at = -INF
			_loops.erase(key)
		return
	if v != null:
		return
	var f := StringName(str((r.get("files", []) as Array)[0]))
	var k: int = _n.get(cls, 0)
	_n[cls] = k + 1
	v = _free_voice()
	if v == null:
		return
	_start(v, DIR % f, h01("%s|%s|%d|o" % [deck, cls, k]) * float(file_info(f).get("len", 1.0)) * 0.9, 1.0)
	v.id = cls
	v.loop = true
	v.env = 0.0
	v.rate = 1.0 / maxf(0.02, float(r.get("fin", 0.05)))
	_loops[key] = v
	var dark := dk(float(r.get("dark", 0.0)))
	var pan_db := _route(v, x, float(r.get("pan", 0.7)), dark)
	v.dry_db = float(r.get("db", 0.0)) + REF - float(file_info(f).get("loud", -20.0)) + dark_comp(f, dark) + pan_db
	v.wet_db = v.dry_db + linear_to_db(float(r.get("wet", plan.get("wet_base", 0.2))))
	_log(cls, f, x, float(r.get("db", 0.0)))


# ------------------------------------------------------------------ the decks' pictures
## The Promenade: the nearest walker's steps, each on a foot-down frame; unclaimed's failing lamp on each strike.
func _promenade(shop: ShopScene) -> void:
	if shop == null:
		return
	var ws := shop.walkers_seen()
	var tall := 1.0
	var near := -1
	for i in ws.size():
		tall = maxf(tall, float(ws[i]["fh"]))
		if bool(ws[i]["seen"]) and not bool(ws[i]["fly"]) and (near < 0 or float(ws[i]["fh"]) > float(ws[near]["fh"])):
			near = i
	for i in ws.size():
		var w: Dictionary = ws[i]
		var id := "w%d" % int(w["id"])
		var fr := int(w["frame"])
		var frames := int(w["frames"])
		var prev: Variant = _seen.get(id)
		if i == near and prev != null and fr != int(prev) and _contact(fr, frames):
			shot(&"step", float(w["x"]), snappedf(1.0 - float(w["fh"]) / tall, 0.01))
		_seen[id] = fr
	var lamp := shop.flick_level()
	var was := float(_seen.get("lamp", lamp))
	var calm := float(_seen.get("calm", 0.0))
	if absf(lamp - was) > 0.05:
		if calm > 1.0:
			shot(&"lamp", MID_X, 0.0)
		calm = 0.0
	else:
		calm += get_process_delta_time()
	_seen["lamp"] = lamp
	_seen["calm"] = calm


static func _contact(fr: int, frames: int) -> bool:
	if frames <= 2:
		return fr == 0 or fr == 1
	return fr == 0 or fr == roundi(frames / 2.0) % frames


## The Exchange: a ship passing, felt through the hull: started its lead before it crosses the middle.
func _exchange(ex: ExchangeScene) -> void:
	if ex == null:
		return
	var now := ex.room_clock()
	for p: Dictionary in ex.passes(MID_X):
		var cls := &"pass_far" if bool(p["far"]) else &"pass"
		_due("pass%d" % int(p["n"]), cls, now, float(p["cross"]), float(p["x"]))


## A shot whose action comes at `at` (a clock's time) and that must start `lead_of` before it: started once, on the
## first frame at or after its start (not at all if that frame is half a second late: the deck was not up).
func _due(key: String, cls: StringName, now: float, at: float, x: float) -> void:
	if _seen.has(key) or now < at - lead_of(cls):
		return
	_seen[key] = true
	if now < at - lead_of(cls) + 0.5:
		shot(cls, x, 0.0, maxf(0.0, at - now))


# ------------------------------------------------------------------ the yard (from YardSound, on the yard's clock)
## One tick of the yard: the welder's arc, the forklift, the flyers' passes, and the rare events with a contact.
func yard_tick(y: YardScene, yt: float) -> void:
	if _quiet or deck != &"yard" or y == null or y.life == null:
		return
	var dt := yt - _yt if _yt >= 0.0 else 0.0
	_yt = yt
	var L := y.life
	var xf := y.get_global_transform_with_canvas()
	span(&"weld", bool(L.weld_now.get("on", false)), (xf * Vector2(float(L.weld_now.get("x", 0.0)), 0.0)).x)
	_fork_track(L, xf, dt)
	if _riding:
		return
	for f: Dictionary in L.AMB:
		var v := float(f["dir"]) * float(f["v"])
		if absf(v) > 0.01:
			_due("fly%.3f" % float(f["t0"]), &"flyer", yt, float(f["t0"]) + (YARD_MID - float(f["x0"])) / v, MID_X)
	_edge(&"hatch", float(L.HEAD.get("t0", -1.0)), (xf * YardLife.HATCH).x)
	_edge(&"console", float(L.CRASH.get("t0", -1.0)), (xf * Vector2(float(YardLife.DESK["cx"]), 0.0)).x)
	if y.light != null:
		_edge(&"bulb", y.light.pop_t0, MID_X)
	if y.drones != null:
		for b: Dictionary in y.drones.bonks:
			var bx := 0.5 * (float((b["a"] as Dictionary).get("x", 0.0)) + float((b["b"] as Dictionary).get("x", 0.0)))
			_due("bonk%.3f" % float(b["t0"]), &"bump", yt, float(b["t0"]), (xf * Vector2(bx, 0.0)).x)


## A rare event the life starts at `t0`: its sound once, as soon as it shows.
func _edge(cls: StringName, t0: float, x: float) -> void:
	if t0 <= 0.0:
		return
	var key := "%s%.3f" % [cls, t0]
	if _seen.has(key):
		return
	_seen[key] = true
	if _yt - t0 < 0.5:
		shot(cls, x)


## The forklift: heard while it moves, louder the faster it drives or lifts, panned with it (the mixer's curve).
func _fork_track(L: YardLife, xf: Transform2D, dt: float) -> void:
	var on := bool(L.FORKLIT.get("on", false))
	var fx := float(L.FK.get("x", -999.0))
	var lift := float(L.FK.get("lift", 0.0))
	var g := 0.0
	if on and dt > 0.0 and _seen.has("fx"):
		var sp := absf(fx - float(_seen["fx"])) / dt
		var ls := absf(lift - float(_seen["lift"])) / dt
		g = clampf(clampf(sp / 25.0, 0.0, 1.0) * 0.85 + clampf(ls / 10.0, 0.0, 1.0) * 0.5, 0.0, 1.0)
	if dt > 0.0:
		var a := clampf(dt / 0.1, 0.0, 1.0)
		_seen["fork_g"] = lerpf(float(_seen.get("fork_g", 0.0)), g, a)
	_seen["fx"] = fx
	_seen["lift"] = lift
	_seen["fork_x"] = (xf * Vector2(fx + 40.0, 0.0)).x


func _fork() -> void:
	if _seen.has("fork_x"):
		_curve(&"fork", float(_seen.get("fork_g", 0.0)), float(_seen["fork_x"]))


# ------------------------------------------------------------------ the PA
## The table's chime and bang ({} where it has none).
static func pa_extra(key: String) -> Dictionary[String, Variant]:
	if _pa_extra.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PA_TABLE))
		if d is Dictionary:
			for k: String in ["chime", "bang"]:
				_pa_extra[k] = (d as Dictionary).get(k, {})
	var out: Dictionary[String, Variant] = {}
	out.assign(_pa_extra.get(key, {}))
	return out


## A row of the table by id ({} if none).
static func pa_row(id: String) -> Dictionary[String, Variant]:
	if _pa_ids.is_empty():
		for r in pa_rows():
			_pa_ids[String(r.get("id", ""))] = r
	var out: Dictionary[String, Variant] = {}
	out.assign(_pa_ids.get(id, {}))
	return out


## Whether a row can be dealt here (`play` its role in the table): its tier, its decks if it names any, the line it
## needs heard first this docking if any, and its file on disk.
static func pa_fits(r: Dictionary, play: String, tr: String, dk: StringName, heard: Dictionary) -> bool:
	if r.is_empty() or String(r.get("play", "bag")) != play or not (r.get("tiers", TIERS) as Array).has(tr):
		return false
	var decks: Array = r.get("decks", [])
	if not decks.is_empty() and not decks.has(String(dk)):
		return false
	var need := String(r.get("needs", ""))
	if need != "" and not heard.has(need):
		return false
	return ResourceLoader.exists(String(r.get("file", "")))


## The next line for here from the bag (`play` "bag") or the dock lines' own (`play` "dock"). The bags last the run:
## drawn from the back; when none in it fits here, the lines it no longer holds go in at the front, shuffled, so what
## is left is heard first. Never the same `when` twice running, nor the same line, while another fits. {} if none fits.
static func pa_draw(play: String, tr: String, dk: StringName, heard: Dictionary) -> Dictionary[String, Variant]:
	var bag: Array[String] = _pa_dock_bag if play == "dock" else _pa_bag
	var fits := func(id: String) -> bool: return pa_fits(pa_row(id), play, tr, dk, heard)
	if not bag.any(fits):
		var fresh: Array[String] = []
		for r in pa_rows():
			var id := String(r.get("id", ""))
			if String(r.get("play", "bag")) == play and not bag.has(id):
				fresh.append(id)
		for i in range(fresh.size() - 1, 0, -1):
			var j := pa_rng.randi_range(0, i)
			var s := fresh[i]
			fresh[i] = fresh[j]
			fresh[j] = s
		fresh.append_array(bag)
		bag.assign(fresh)
	var pick := -1
	var best := -1
	for i in range(bag.size() - 1, -1, -1):
		var r := pa_row(bag[i])
		if not pa_fits(r, play, tr, dk, heard):
			continue
		var score := 2 if String(r.get("when", "")) != _pa_last_when else (1 if bag[i] != _pa_last_id else 0)
		if score > best:
			best = score
			pick = i
		if score == 2:
			break
	if pick < 0:
		return {}
	var out := pa_row(bag[pick])
	bag.remove_at(pick)
	_pa_last_when = String(out.get("when", ""))
	_pa_last_id = String(out.get("id", ""))
	return out


## Every file the PA can play at a tier: its lines there, the chime and the bang.
func _pa_files(tr: String) -> Array[String]:
	var out: Array[String] = [String(pa_extra("chime").get("file", "")), String(pa_extra("bang").get("file", ""))]
	for r in pa_rows():
		if (r.get("tiers", TIERS) as Array).has(tr):
			out.append(String(r.get("file", "")))
	return out


func pa_busy() -> bool:
	return _pa != null and _pa.busy and _pa.id == &"pa"


## The PA silent and owing nothing (the tests): no follow-up due, no line waiting on its chime, none playing.
func pa_quiet() -> void:
	_pa_after.clear()
	_pa_line = {}
	_pa_line_at = INF
	if pa_busy():
		_stop(_pa)


## The PA, each frame of a deck with a speaker: the dock line or a bag line when one is due, a follow-up when its
## time comes, the steps of the one being read (bang, chime, line); never in a ride, one at a time.
func _pa_tick() -> void:
	var pa: Dictionary = plan.get("pa", {})
	if pa_busy():
		_tape_env()
	if pa.is_empty():
		return
	if _riding:
		if _pa_line_at < INF:
			_pa_cancel()
		return
	if t >= _pa_line_at:
		_pa_step(pa)
		return
	if _pa_line_at < INF or pa_busy():
		return
	for i in _pa_after.size():
		var f: Dictionary = _pa_after[i]
		if t >= float(f["at"]):
			_pa_after.remove_at(i)
			if t - float(f["at"]) < PA_AFTER_LATE and pa_fits(f["row"], "after", tier, deck, _pa_heard):
				announce(f["row"])
			return
	if t < _pa_next:
		return
	var r: Dictionary = {}
	if _pa_dock_due:
		r = pa_draw("dock", tier, deck, _pa_heard)
	_pa_dock_due = false
	if r.is_empty():
		r = pa_draw("bag", tier, deck, _pa_heard)
	if r.is_empty():
		# (nothing in the table fits here now: try again a gap on)
		_pa_next = t + pa_rng.randf_range(PA_GAP.x, PA_GAP.y)
		return
	announce(r)


## A line as the PA reads it: the reactor's bang first if the line follows one, the chime if it has one, then the line.
func announce(r: Dictionary) -> void:
	var pa: Dictionary = plan.get("pa", {})
	_pa_line = r
	_pa_chimed = not bool(r.get("chime", false)) or pa_extra("chime").is_empty()
	_pa_line_at = t
	if bool(r.get("bang", false)) and not pa_extra("bang").is_empty():
		_pa_bang(pa)
		_pa_line_at = t + BANG_LEAD
	if t >= _pa_line_at:
		_pa_step(pa)


func _pa_step(pa: Dictionary) -> void:
	if not _pa_chimed:
		_pa_chimed = true
		_pa_chime(pa)
		_pa_line_at = t + float(pa_extra("chime").get("lead", 2.0))
		return
	var r := _pa_line
	_pa_line = {}
	_pa_line_at = INF
	say(r, pa)


## A line waiting on its chime goes with it (a ride, a deck changed): the next comes sooner than a gap.
func _pa_cancel() -> void:
	_pa_line = {}
	_pa_line_at = INF
	_pa_next = minf(_pa_next, t + pa_rng.randf_range(PA_FIRST.x, PA_FIRST.y))


## A PA voice through this deck's speaker: its buses, its pan, its level for a file of loudness `loud`.
func _pa_voice(v: Voice, pa: Dictionary, path: String, loud: float, secs: float) -> void:
	var kind := String(pa.get("speaker", "clear"))
	_start(v, path, 0.0, 1.0)
	if _live:
		v.dry.bus = StationBus.pa_bus(kind, false)
		v.wet.bus = StationBus.pa_bus(kind, true)
	v.loop = false
	v.env = 1.0
	v.rate = 0.0
	v.ends = t + secs + 0.1
	var pn := HangarSound.pan_for(float(pa.get("x", MID_X)), 0.5)
	if _live:
		StationBus.route(v.dry.bus, pn.x, 0.0)
		StationBus.route(v.wet.bus, pn.x, 0.0)
	var comp := float((data().get("speaker_db", {}) as Dictionary).get(kind, 0.0))
	v.dry_db = REF + float(plan.get("ref_db", 0.0)) + float(pa.get("db", 0.0)) - loud + comp + pn.y
	v.wet_db = v.dry_db + linear_to_db(maxf(float(pa.get("wet", 0.1)), 1e-4))


## The staff chime, through the speaker, where it sat on the old take it was cut from (`ref_loud`).
func _pa_chime(pa: Dictionary) -> void:
	var c := pa_extra("chime")
	var v := _free_voice()
	if v == null:
		return
	_pa_voice(v, pa, String(c.get("file", "")), float(c.get("ref_loud", -26.0)), float(c.get("secs", 2.5)))
	v.id = &"pa_chime"
	_log(&"pa_chime", &"pa_chime", float(pa.get("x", MID_X)), float(pa.get("db", 0.0)))


## The reactor venting: a heavy game sound far off, through the deck's room (dark, wet), at the PA's level for the deck.
func _pa_bang(pa: Dictionary) -> void:
	var b := pa_extra("bang")
	var v := _free_voice()
	if v == null:
		return
	var path := String(b.get("file", ""))
	_start(v, path, 0.0, 1.0)
	v.id = &"pa_bang"
	v.loop = false
	v.env = 1.0
	v.rate = 0.0
	v.ends = t + float(b.get("secs", 3.0)) + 0.05
	var dark := dk(float(b.get("dark", 1.0)))
	var pan_db := _route(v, float(pa.get("x", MID_X)), 0.5, dark)
	var rel := float(b.get("db", 0.0)) + float(pa.get("db", 0.0))
	v.dry_db = rel + REF + float(plan.get("ref_db", 0.0)) - float(b.get("loud", -20.0)) \
		+ _lp_at(b.get("lp", []), dark) + pan_db
	v.wet_db = v.dry_db + linear_to_db(maxf(float(b.get("wet", 0.5)), 1e-4))
	_log(&"pa_bang", StringName(path.get_file().get_basename()), float(pa.get("x", MID_X)), rel)


## Read one row of the table now, through `pa`'s speaker (the tests call it): no chime (`announce` has it). Its
## follow-up, if it leads one, is rolled now; a bag or dock line sets when the next is due.
func say(r: Dictionary, pa: Dictionary) -> void:
	var kind := String(pa.get("speaker", "clear"))
	var v := _free_voice()
	if v == null:
		return
	_pa = v
	_pa_tape = kind.begins_with("tape")
	_pa_cut = false
	_pa_len = float(r.get("secs", 10.0))
	_pa_cut_at = minf(float(r.get("cut", _pa_len)), _pa_len)
	_pa_t0 = t
	_pa_voice(v, pa, String(r.get("file", "")), float(r.get("loud", -20.0)), _pa_cut_at if _pa_tape else _pa_len)
	v.id = &"pa"
	var id := String(r.get("id", ""))
	var play := String(r.get("play", "bag"))
	_pa_heard[id] = true
	if play != "after":
		_pa_next = t + _pa_len + pa_rng.randf_range(PA_GAP.x, PA_GAP.y)
		pa_follow(id)
	_log(&"pa", StringName(id), float(pa.get("x", MID_X)), float(pa.get("db", 0.0)),
		{"speaker": kind, "tape": _pa_tape, "play": play, "cut": _pa_cut_at if _pa_tape else -1.0})


## About one lead in three gets its follow-up (a row whose `after` names the lead's start), 5-10 s after it ends.
func pa_follow(id: String) -> void:
	var fs: Array[Dictionary] = []
	for r in pa_rows():
		if String(r.get("play", "")) != "after" or not pa_fits(r, "after", tier, deck, _pa_heard):
			continue
		for p: Variant in r.get("after", []):
			if id.begins_with(String(p)):
				fs.append(r)
				break
	if fs.is_empty() or pa_rng.randf() >= PA_AFTER_P:
		return
	_pa_after.append({"row": fs[pa_rng.randi_range(0, fs.size() - 1)],
		"at": t + _pa_len + pa_rng.randf_range(PA_AFTER.x, PA_AFTER.y)})


## The unclaimed tape: its wow and flutter, two dropouts, and the cut where its row's line stops (`cut`, s) with a
## clunk (the mixer's).
func _tape_env() -> void:
	if not _pa_tape:
		return
	var tt := t - _pa_t0
	var u := tt / maxf(0.1, _pa_len)
	var g := 1.0
	for d: Array in TAPE_DIPS:
		if u >= float(d[0]) and u < float(d[1]):
			g = float(d[2])
	_pa.level = g
	if _live:
		var wow := 1.0 + 0.006 * TAU * 0.55 * cos(TAU * 0.55 * tt) + 0.002 * TAU * 6.3 * cos(TAU * 6.3 * tt + 1.0)
		_pa.dry.pitch_scale = wow
		_pa.wet.pitch_scale = wow
	if tt >= _pa_cut_at and not _pa_cut:
		_pa_cut = true
		_pa.rate = -1.0 / 0.005
		_pa.stop_at = -INF
		var v := _free_voice()
		if v != null:
			_start(v, DIR % &"pa_tape_clunk", 0.0, 1.0)
			v.id = &"pa_clunk"
			v.loop = false
			v.env = 1.0
			v.rate = 0.0
			v.ends = t + 0.2
			_route(v, float((plan.get("pa", {}) as Dictionary).get("x", MID_X)), 0.5, 0.0)
			v.dry_db = _pa.dry_db + 20.0 * log(0.03 / 0.1) / log(10.0)
			v.wet_db = _pa.wet_db + 20.0 * log(0.03 / 0.1) / log(10.0)
			_log(&"pa_clunk", &"pa_tape_clunk", MID_X, 0.0, {"at": tt})


# ------------------------------------------------------------------ the Board's own sounds
## One of the Board's own sounds (a strike, a flicker, a screen's power-on, an ad, a popup): through the Board's
## room as the mix had it (its tamed copy, at its plan level), or `Audio.play` as before anywhere else.
static func keep(name: StringName) -> void:
	var s := _shared
	if s == null or s.deck != &"board" or not (s.plan.get("keep", {}) as Dictionary).has(String(name)):
		Audio.play(name, 0.0)
		return
	s._keep(name)


func _keep(name: StringName) -> void:
	var k: Dictionary = (plan.get("keep", {}) as Dictionary)[String(name)]
	var f := StringName(str(k.get("file", "")))
	var v := _free_voice()
	if v == null:
		return
	_start(v, DIR % f, 0.0, 1.0)
	v.id = name
	v.loop = false
	v.env = 1.0
	v.rate = 0.0
	v.ends = t + float(file_info(f).get("len", 1.0)) + 0.05
	var pan_db := _route(v, MID_X, 0.7, 0.0)
	v.dry_db = float(k.get("db", 0.0)) + REF - float(file_info(f).get("loud", -20.0)) + pan_db
	v.wet_db = v.dry_db + linear_to_db(float(plan.get("wet_base", 0.12)))
	_log(name, f, MID_X, float(k.get("db", 0.0)))
