class_name DeskAudio
extends Node

## The science desk's sound, as the approved page plays it (`scenes/audio.js`): the cabin bed under
## every room, the lamp's click, the monitor's power-on (G), and the CRT hum that warms up from G's
## thunk and holds while you sit there. Leaving plays the game's own quit sound, its click where the
## screen goes dark, the hum coasting down into it, and the lamp clicks off.
## Why: docs/why/DeskScene.md#sound

const BED := preload("res://assets/audio/desk/desk_bed.wav")
const HUM := preload("res://assets/audio/desk/desk_hum.wav")
## The bed and the hum go on Ambient, the clicks on SFX, so the volume settings hold.
const HUM_BUS := &"DeskHum"
## The page's mix, kept: everything at the file's level but the hum (+14 dB, a little over the bed)
## and the quit sound, 22 dB under (it is mastered hot; there it lands near G's loudest moment).
## Why: docs/why/DeskScene.md#sound
const BED_DB := 0.0
const HUM_DB := 14.0
const OFF_DB := -22.0
## The hum's warm-up: gain to 1.25 by 1.6 s, then 1 by 2.4 s; pitch 0.9 to 1 over 2 s; a low-pass
## from 160 Hz to 20 kHz over 2.2 s (exponential), so the whine comes in last.
const WARM_PEAK := 1.25
const WARM_PEAK_AT := 1.6
const WARM_SETTLE_AT := 2.4
const WARM_RATE0 := 0.9
const WARM_RATE_AT := 2.0
const WARM_LP0 := 160.0
const WARM_LP_AT := 2.2
const LP_TOP := 20000.0
## The hum coasts down like `Audio.power_down` (pitch to 0.3, quad ease-in) and is cut this long
## before the quit sound's click, with a short fade.
const HUM_CUT_LEAD := 0.06
const HUM_CUT_FADE := 0.04
## How fast the bed and the hum follow the room (the page's setTargetAtTime .12 s).
const FOLLOW_S := 0.12

var lamp_at := 3.45
var crt_at := 5.1
## Every sound fired, [name, scene time], for `DeskTest`.
var fired: Array[Array] = []
var _bed: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _lp: AudioEffectLowPassFilter
var _prev := -1.0
var _off_fired := false
var _warm_t := -1.0
var _bed_lv := 0.0
var _hum_lv := 0.0
## The hum's coast: real seconds since it began, and how long until its cut (or < 0: none).
var _coast_t := -1.0
var _coast_len := 0.0
var _coast_r0 := 1.0


func _ready() -> void:
	_bed = _loop_player(BED, &"Ambient")
	_hum = _loop_player(HUM, _hum_bus())


func _loop_player(stream: AudioStreamWAV, bus: StringName) -> AudioStreamPlayer:
	var s := stream.duplicate() as AudioStreamWAV
	Audio.loop_whole(s)
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	return p


## The hum's own bus (a low-pass for its warm-up) into Ambient; made once.
func _hum_bus() -> StringName:
	var i := AudioServer.get_bus_index(HUM_BUS)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, HUM_BUS)
		AudioServer.set_bus_send(i, &"Ambient")
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = LP_TOP
		lp.resonance = 0.5
		AudioServer.add_bus_effect(i, lp)
	_lp = AudioServer.get_bus_effect(i, 0) as AudioEffectLowPassFilter
	return HUM_BUS


## A new visit: forget the last one's clock.
func reset() -> void:
	_prev = -1.0
	_off_fired = false
	_warm_t = -1.0
	_coast_t = -1.0
	fired.clear()


## Once a frame: scene time `ts` (backwards while leaving), `dt` real seconds since the last.
func tick(ts: float, dt: float, is_leaving: bool) -> void:
	for ev: Array in DeskTimeline.sound_events(_prev, ts, is_leaving, lamp_at, crt_at, _off_fired):
		_fire(ev[0], float(ev[1]), ts)
	_prev = ts
	var bed_want := DeskTimeline.bed_level(ts)
	var k := 1.0 - exp(-dt / FOLLOW_S) if dt > 0.0 else 1.0
	_bed_lv += (bed_want - _bed_lv) * k
	_level(_bed, BED_DB, _bed_lv)
	if _coast_t >= 0.0:
		_coast(dt)
		return
	var hum_want := bed_want if ts >= DeskTimeline.hum_at(crt_at) else 0.0
	_hum_lv += (hum_want - _hum_lv) * k
	var warm := 1.0
	if _warm_t >= 0.0:
		_warm_t += dt
		warm = _warm(_warm_t)
	elif hum_want > 0.0 and not _hum.playing:
		_warm_t = WARM_SETTLE_AT  # entered past the moment: no warm-up, it fades in with the room
	if _hum_lv > 0.001 and not _hum.playing:
		_hum.play()
	_level(_hum, HUM_DB, _hum_lv * warm)


func _level(p: AudioStreamPlayer, db: float, lv: float) -> void:
	if lv <= 0.0005:
		p.volume_db = -80.0
		return
	p.volume_db = db + linear_to_db(lv)
	if not p.playing:
		p.play()


## The warm-up's gain at `t` seconds; sets its pitch and low-pass on the way.
func _warm(t: float) -> float:
	_hum.pitch_scale = lerpf(WARM_RATE0, 1.0, clampf(t / WARM_RATE_AT, 0.0, 1.0))
	if _lp != null:
		_lp.cutoff_hz = WARM_LP0 * pow(LP_TOP / WARM_LP0, clampf(t / WARM_LP_AT, 0.0, 1.0))
	if t < WARM_PEAK_AT:
		return WARM_PEAK * t / WARM_PEAK_AT
	if t < WARM_SETTLE_AT:
		return lerpf(WARM_PEAK, 1.0, (t - WARM_PEAK_AT) / (WARM_SETTLE_AT - WARM_PEAK_AT))
	return 1.0


func _coast(dt: float) -> void:
	_coast_t += dt
	var x := clampf(_coast_t / maxf(0.05, _coast_len), 0.0, 1.0)
	_hum.pitch_scale = _coast_r0 + (0.3 - _coast_r0) * x * x
	if _coast_t >= _coast_len:
		var f := clampf(1.0 - (_coast_t - _coast_len) / HUM_CUT_FADE, 0.0, 1.0)
		_level(_hum, HUM_DB, _hum_lv * f)
		if f <= 0.0:
			_hum.stop()


func _fire(name: StringName, v: float, ts: float) -> void:
	fired.append([name, ts])
	match name:
		&"lamp":
			Audio.play(&"desk_lamp", 0.0)
		&"poweron":
			Audio.play(&"desk_poweron", 0.0)
		&"hum_warm":
			_warm_t = 0.0
			_hum.pitch_scale = WARM_RATE0
			_hum.play()
		&"power_off":
			_off_fired = true
			Audio.play(&"power_off", 0.0, 0, OFF_DB, 1.0, v)
			if _hum.playing:
				_coast_t = 0.0
				_coast_r0 = _hum.pitch_scale
				_coast_len = maxf(0.05, DeskTimeline.OFF_CUT - v - HUM_CUT_LEAD)


## Silence now (the desk is gone).
func stop() -> void:
	_bed.stop()
	_hum.stop()
