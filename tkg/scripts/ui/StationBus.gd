class_name StationBus
extends RefCounted

## The station decks' buses, made once and kept (as `HangarSound`'s): `Station` (the mixer's bus EQ, its gentle
## compression, a true-peak ceiling) into Ambient, its hall `StationHall` (one reverb, set per room), a bus per voice
## (pan and the depth low-pass) and one per PA speaker (its filters). Why: docs/why/StationSound.md#the-buses

## The bus EQ's bands each crispness lift goes on (`AudioEffectEQ21`'s, by index), as the hangar's.
const EQ_MUD := [6, 7, 8, 9]
const EQ_PRES := [12, 13, 14, 15, 16]
const EQ_AIR := [17, 18, 19, 20]
## `AudioEffectEQ10`'s band centres, for the PA's bells.
const EQ10_HZ := [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]


static func _bus(n: String, to: StringName) -> int:
	var idx := AudioServer.get_bus_index(n)
	if idx >= 0:
		return idx
	AudioServer.add_bus()
	idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, n)
	AudioServer.set_bus_send(idx, to)
	return idx


## `Station` and `StationHall`, made on first use.
static func master() -> int:
	var made := AudioServer.get_bus_index("Station") >= 0
	var idx := _bus("Station", &"Ambient")
	if made:
		return idx
	var eq := AudioEffectEQ21.new()
	var g: Array = StationSound.data().get("eq21", [])
	for b in mini(g.size(), eq.get_band_count()):
		eq.set_band_gain_db(b, float(g[b]))
	AudioServer.add_bus_effect(idx, eq)
	var c := AudioEffectCompressor.new()
	c.ratio = StationSound.COMP_RATIO
	c.attack_us = 40000.0
	c.release_ms = 600.0
	AudioServer.add_bus_effect(idx, c)
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -3.5
	AudioServer.add_bus_effect(idx, lim)
	var h := _bus("StationHall", &"Station")
	var rv := AudioEffectReverb.new()
	rv.spread = 1.0
	rv.hipass = 0.0
	rv.dry = 0.0
	rv.wet = 1.0
	rv.predelay_feedback = 0.0
	AudioServer.add_bus_effect(h, rv)
	var sh := AudioEffectHighShelfFilter.new()
	sh.cutoff_hz = 5000.0
	AudioServer.add_bus_effect(h, sh)
	return idx


## A voice's bus: its pan, then the mixer's 2nd-order Butterworth run forward and back as two plain 2-pole stages
## (Godot's 24DB is a far steeper slope, which sounded muddy in the hangars). Why: docs/why/StationSound.md#depth-low-pass
static func voice(n: String, to: StringName) -> StringName:
	master()
	var made := AudioServer.get_bus_index(n) >= 0
	var idx := _bus(n, to)
	if not made:
		AudioServer.add_bus_effect(idx, AudioEffectPanner.new())
		for i in 2:
			var lp := AudioEffectLowPassFilter.new()
			lp.resonance = 0.7071
			lp.db = AudioEffectFilter.FILTER_6DB
			AudioServer.add_bus_effect(idx, lp)
	return StringName(n)


## Constant power (the mixer's) as Godot's balance panner takes it: (its pan, the dB to make up).
static func pan_for(x: float, k: float) -> Vector2:
	var p := clampf(x / 960.0 * 2.0 - 1.0, -1.0, 1.0) * k
	var th := (p + 1.0) * PI / 4.0
	var l := cos(th) * sqrt(2.0)
	var r := sin(th) * sqrt(2.0)
	return Vector2((r - l) / (r + l), linear_to_db((r + l) * 0.5))


## A voice's pan (Godot's balance) and darkness (0: no low-pass; else 7 kHz down toward 1.8 kHz).
static func route(bus: StringName, pan: float, dark: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	(AudioServer.get_bus_effect(idx, 0) as AudioEffectPanner).pan = pan
	if not String(bus).begins_with("StationDry") and not String(bus).begins_with("StationWet"):
		return
	for e in [1, 2]:
		(AudioServer.get_bus_effect(idx, e) as AudioEffectFilter).cutoff_hz = 7000.0 - 5200.0 * dark
		AudioServer.set_bus_effect_enabled(idx, e, dark > 0.0)


## A PA speaker's bus (dry into the room's bus, or wet into its hall): its high-pass and low-pass stages and bells,
## as `station.json` lists them (`tools/dev/station_sound.py`, SPEAKERS).
static func pa_bus(kind: String, wet: bool) -> StringName:
	master()
	var n := ("StationPAW_%s" if wet else "StationPA_%s") % kind
	if AudioServer.get_bus_index(n) >= 0:
		return StringName(n)
	var idx := _bus(n, &"StationHall" if wet else &"Station")
	AudioServer.add_bus_effect(idx, AudioEffectPanner.new())
	var sp: Dictionary = (StationSound.data().get("speakers", {}) as Dictionary).get(kind, {})
	for f: Variant in sp.get("hp", []):
		var hp := AudioEffectHighPassFilter.new()
		hp.cutoff_hz = float(f)
		hp.resonance = 0.7071
		hp.db = AudioEffectFilter.FILTER_6DB
		AudioServer.add_bus_effect(idx, hp)
	for f: Variant in sp.get("lp", []):
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = float(f)
		lp.resonance = 0.7071
		lp.db = AudioEffectFilter.FILTER_6DB
		AudioServer.add_bus_effect(idx, lp)
	var bells: Dictionary = sp.get("bell", {})
	if not bells.is_empty():
		var eq := AudioEffectEQ10.new()
		for hz: Variant in bells:
			eq.set_band_gain_db(EQ10_HZ.find(int(str(hz))), float(bells[hz]))
		AudioServer.add_bus_effect(idx, eq)
	return StringName(n)


## A room shown: its bus level and threshold, its hall, and its crispness on the bus EQ.
static func set_room(plan: Dictionary, live: bool) -> void:
	if not live:
		return
	var idx := master()
	var key := StringName("%s:%s" % [plan.get("deck", ""), plan.get("tier", "")])
	var bus: Dictionary = plan.get("bus", {})
	var crisp: Dictionary = plan.get("crisp", {})
	AudioServer.set_bus_volume_db(idx, float(bus.get("gain_db", -11.0)) + float(StationSound.LEVEL_TRIM.get(key, 0.0)))
	var c := AudioServer.get_bus_effect(idx, 1) as AudioEffectCompressor
	c.threshold = float(bus.get("thr_rms_db", -23.0)) + StationSound.COMP_DETECT
	var eq := AudioServer.get_bus_effect(idx, 0) as AudioEffectEQ21
	var g: Array = StationSound.data().get("eq21", [])
	for b in mini(g.size(), eq.get_band_count()):
		var add := 0.0
		if b in EQ_MUD:
			add = float(crisp.get("mud", 0.0))
		elif b in EQ_PRES:
			add = float(crisp.get("pres", 0.0))
		elif b in EQ_AIR:
			add = float(crisp.get("air", 0.0))
		eq.set_band_gain_db(b, float(g[b]) + add)
	var hall: Dictionary = plan.get("hall", {})
	var h := AudioServer.get_bus_index("StationHall")
	var rv := AudioServer.get_bus_effect(h, 0) as AudioEffectReverb
	rv.room_size = float(hall.get("room", 0.5))
	rv.damping = float(hall.get("damp", 0.5))
	rv.predelay_msec = float(hall.get("predelay", 40.0))
	# (the hangar's shelf levels are 0.5 at A and 0.8 at B2: a room's crispness scales its own the same way)
	(AudioServer.get_bus_effect(h, 1) as AudioEffectHighShelfFilter).gain = float(hall.get("shelf", 0.25)) \
		* float(crisp.get("shelf", 0.5)) / 0.5
	AudioServer.set_bus_volume_db(h, float(hall.get("db", -10.0)) + float(crisp.get("hall_db", 0.0)))
