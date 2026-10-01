class_name YardSound
extends Node

## The Yard, heard, as Jon set it on the Yard Drones page's sound panel (v46,
## "bed 1 at 0 dB · welder 1 at 0 dB · drones in and out 2 at -6 st, wind-down
## 30%, 0 dB, at work: patch 1/2, repair 1/2, refuel 2/3, faults 2/3 at 0 dB ·
## now and then: clank 1, clank 2, clank 3, airtool 1, airtool 2, hiss 2, hiss
## 3, hoist 1, hoist 2 at 0 dB, every 15-30 s"):
##
##   the deal TV     powers on in its lab's sounds, each level its own ("Each
##                   TV turning on should be treated different"), at the times
##                   its lights strike
##   the bed         one loop under every level, rising as you come onto the
##                   deck and gone when you leave it
##   now and then    the hall's distant work, one take every 15 to 30 s, never
##                   the same twice running and another kind when there is one
##   the welder      his arc, on while it burns and off when he lowers the
##                   torch, a little to the right where he stands
##   the drones      a whir in, winding down as each brakes to a hover and
##                   stopping at 1.6 s ("ramp it down less aggressively": 30%),
##                   the same whir whole as they fly away, both six semitones
##                   down; and each service's own sound as its work lands on the
##                   hull, panned to where it happens. Hovering is silent.
##   the flickers    a light that stutters ticks on the frame it goes dark: a
##                   70 ms slice of its lab's flicker, cut off by the next, so a
##                   buzzing bulb crackles exactly as fast as it flashes; a pop
##                   snaps louder
##
## Every file's level is baked in (LUFS-matched to the labs' sounds): all of it
## plays at 0 dB on the Ambient bus, beside the station's crowd and PA. None of
## it in the sim or a headless run.

const POWER_ON_SOUNDS := {
	"unclaimed": [[0.3, &"lab_unclaimed_bulb"], [0.6, &"lab_unclaimed_bulb"], [1.0, &"lab_unclaimed_bulb"],
		[1.1, &"lab_unclaimed_bulb"], [1.2, &"lab_unclaimed_bulb"], [1.6, &"lab_unclaimed_screen"], [2.2, &"lab_unclaimed_static"]],
	"outpost": [[1.12, &"lab_outpost_status"], [1.36, &"lab_outpost_status"], [1.6, &"lab_outpost_status"],
		[2.1, &"lab_outpost_screen"], [2.7, &"lab_outpost_static"]],
	"settlement": [[0.3, &"lab_settlement_lamp"], [1.7, &"lab_settlement_screen"], [2.75, &"lab_settlement_static"]],
	"city": [[0.3, &"lab_city_hood"], [2.3, &"lab_monitor_pop"], [2.9, &"lab_city_screen"]],
	"capital": [[0.3, &"lab_capital_bar"], [1.5, &"lab_capital_tanks"], [2.2, &"lab_monitor_pop"], [3.0, &"lab_capital_glass"]],
}
const FLICKS := {
	"unclaimed": [&"lab_unclaimed_flicker"], "outpost": [&"lab_outpost_flicker"], "settlement": [&"lab_settlement_flicker"],
	"city": [&"lab_city_flicker_a", &"lab_city_flicker_b"], "capital": [],
}
const SHOTS := [&"yard_clank_1", &"yard_clank_2", &"yard_clank_3", &"yard_airtool_1", &"yard_airtool_2",
	&"yard_hiss_2", &"yard_hiss_3", &"yard_hoist_1", &"yard_hoist_2"]
const WORK := {0: [&"yard_patch_1", &"yard_patch_2"], 1: [&"yard_repair_1", &"yard_repair_2"],
	2: [&"yard_refuel_2", &"yard_refuel_3"], 3: [&"yard_faults_2", &"yard_faults_3"]}
## The drones' whir, six semitones down, and how far it winds down as they brake.
const DRONE_ST := -6.0
const WIND_DOWN := 0.30
const PAN_BUSES := 8
const WELD_PAN := 0.35
## Seconds between the now-and-then sounds.
static var shot_every := Vector2(15.0, 30.0)

var scene: YardScene
var _cache: Dictionary = {}
var _bed: AudioStreamPlayer
var _bed_fade: Tween = null
var _bed_on := false
var _voices: Array[AudioStreamPlayer] = []
var _vnext := 0
var _pan: Array[AudioStreamPlayer] = []
var _pan_bus: Array[StringName] = []
var _pnext := 0
var _weld: AudioStreamPlayer
var _weld_was := false
var _weld_fade: Tween = null
## Each flickering light's voice, so the next slice cuts the last off.
var _flick: Dictionary = {}
var _flick_turn := 0
var _drop: Dictionary = {}
## The drones winding down: [player, started, rate, gain].
var _winding: Array = []
var _heard := 0
var _tp := 0.0
var _powered := false
var _shot_at := 0.0
var _last_shot := &""
var _last_work: Dictionary = {}
var _was_visible := false


func _ready() -> void:
	_bed = _player(&"Ambient")
	for i in 6:
		_voices.append(_player(&"Ambient"))
	for i in PAN_BUSES:
		var bus := _pan_bus_named("YardPan%d" % i)
		_pan_bus.append(bus)
		_pan.append(_player(bus))
	_weld = _player(_pan_bus_named("YardWeld"))
	_set_pan(&"YardWeld", WELD_PAN)


func _player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


## A bus that pans what plays on it and sends it on to Ambient: made once, kept.
static func _pan_bus_named(n: String) -> StringName:
	var idx := AudioServer.get_bus_index(n)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, n)
		AudioServer.add_bus_effect(idx, AudioEffectPanner.new())
		AudioServer.set_bus_send(idx, &"Ambient")
	return StringName(n)


static func _set_pan(bus: StringName, pan: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0 or AudioServer.get_bus_effect_count(idx) < 1:
		return
	var fx := AudioServer.get_bus_effect(idx, 0) as AudioEffectPanner
	if fx != null:
		fx.pan = clampf(pan, -1.0, 1.0)


static func pan_of(x: float) -> float:
	return clampf((x - 383.0) / 383.0 * 0.8, -0.8, 0.8)


func _stream(name: StringName, dir: String = "sfx") -> AudioStream:
	var key := dir + "/" + String(name)
	if not _cache.has(key):
		var s: AudioStream = load("res://assets/audio/%s/%s.wav" % [dir, name])
		if s == null:
			push_warning("yard: missing sound %s" % key)
		_cache[key] = s
	return _cache[key]


## A wav that joins on itself, looped on its own length (ogg clicks at a seam).
func _loop(name: StringName, dir: String) -> AudioStream:
	var s := _stream(name, dir)
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = roundi(w.get_length() * float(w.mix_rate))
	return s


func _taped(name: StringName) -> void:
	if Audio.taping:
		Audio.tape.append([name, Time.get_ticks_msec(), 0.0, 1.0])


## `settled`: the power-on was heard earlier this docking, so none of it again.
func power_on(tp: float, settled: bool = false) -> void:
	_tp = tp
	_powered = true
	_heard = POWER_ON_SOUNDS.get(scene.level, []).size() if settled else 0
	# the now-and-then counts from now, not from a power-on long past
	_shot_at = tp + (YardScene.SETTLED if settled else 0.0) + randf_range(shot_every.x, shot_every.y)


## Each tick of the yard's clock: the TV's power-on sounds that are due, the
## now-and-then, the welder, and the lights' dropouts.
func tick(t: float, tb: float) -> void:
	if YardScene.pin_clock >= 0.0:
		return
	if not _bed_on:
		_bed_start()
	var plan: Array = POWER_ON_SOUNDS.get(scene.level, [])
	while _powered and _heard < plan.size() and float(plan[_heard][0]) <= tb:
		Audio.play(plan[_heard][1], 0.0)
		_heard += 1
	if t >= _shot_at and _powered:
		_shot()
		_shot_at = t + randf_range(shot_every.x, shot_every.y)
	_welder()
	_dropouts()


## A light's dropout, heard on the frame it goes dark (a lamp, or a glow that
## stutters); a flash dying is the snap, not a second tick.
func _dropouts() -> void:
	var L := scene.light
	for n in L.nlights:
		var d: Dictionary = L.lights[n]
		var kind := String(d.get("kind", ""))
		if kind != "ceil" and not (kind == "glow" and bool(d.get("sfx", false))):
			continue
		var w := L.ew[n] if kind == "glow" else L.nw[n]
		var was := float(_drop.get(n, w))
		if was >= 0.6 and was < 1.5 and w <= 0.35:
			flick(str(n))
		elif was < 1.5 and w >= 1.5:
			flick(str(n), true)
		_drop[n] = w


func flick(key: String, strong: bool = false) -> void:
	var names: Array = FLICKS.get(scene.level, [])
	if names.is_empty():
		return
	var name: StringName = names[_flick_turn % names.size()]
	_flick_turn += 1
	var s := _stream(name)
	if s == null:
		return
	var p: AudioStreamPlayer = _flick.get(key)
	if p == null:
		p = _player(&"Ambient")
		_flick[key] = p
	p.stop()
	var dur := 0.12 if strong else 0.07
	var g := 0.55 if strong else 0.32
	p.stream = s
	p.volume_db = linear_to_db(g)
	p.play(0.01 + randf() * 0.22)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: p.volume_db = linear_to_db(maxf(v, 0.0001)), g, 0.0001, dur)
	tw.tween_callback(p.stop)
	_taped(name)


func _bed_start() -> void:
	_bed_on = true
	var s := _loop(&"yard_bed", "ambience")
	if s == null:
		return
	_bed.stream = s
	_bed.volume_db = -60.0
	_bed.play()
	if _bed_fade != null and _bed_fade.is_valid():
		_bed_fade.kill()
	_bed_fade = create_tween()
	_bed_fade.tween_property(_bed, ^"volume_db", 0.0, 1.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_taped(&"yard_bed")


## One of the takes, never the one just heard, and another kind if there is one.
func _shot() -> void:
	var kind := String(_last_shot).split("_")[1] if _last_shot != &"" else ""
	var pool: Array = SHOTS.filter(func(n: StringName) -> bool: return n != _last_shot and String(n).split("_")[1] != kind)
	if pool.is_empty():
		pool = SHOTS.filter(func(n: StringName) -> bool: return n != _last_shot)
	var name: StringName = pool[randi() % pool.size()]
	_last_shot = name
	_play(name, 0.0)


func _play(name: StringName, db: float) -> void:
	var s := _stream(name)
	if s == null:
		return
	var p := _voices[_vnext]
	_vnext = (_vnext + 1) % _voices.size()
	p.stream = s
	p.pitch_scale = 1.0
	p.volume_db = db
	p.play()
	_taped(name)


## The welder's arc: the loop starts the frame it strikes, somewhere it can run
## 4.2 s from without reaching its seam, and fades out the frame it goes off.
func _welder() -> void:
	var on := bool(scene.life.weld_now.get("on", false))
	if on == _weld_was:
		return
	_weld_was = on
	if _weld_fade != null and _weld_fade.is_valid():
		_weld_fade.kill()
	if not on:
		_weld_fade = create_tween()
		_weld_fade.tween_property(_weld, ^"volume_db", -60.0, 0.12)
		_weld_fade.tween_callback(_weld.stop)
		return
	var s := _loop(&"yard_weld", "sfx")
	if s == null:
		return
	_weld.stream = s
	_weld.volume_db = -60.0
	_weld.play(randf() * maxf(0.0, s.get_length() - 4.3))
	_weld_fade = create_tween()
	_weld_fade.tween_property(_weld, ^"volume_db", 0.0, 0.015)
	_taped(&"yard_weld")


func _panned(name: StringName, x: float) -> AudioStreamPlayer:
	var s := _stream(name)
	if s == null:
		return null
	var i := _pnext
	_pnext = (_pnext + 1) % _pan.size()
	var p := _pan[i]
	_set_pan(_pan_bus[i], pan_of(x))
	p.stream = s
	p.pitch_scale = 1.0
	p.volume_db = 0.0
	return p


## A drone flying in: the whir winds down with it as it brakes to a hover, and
## stops at 1.6 s.
func arrive(x: float) -> void:
	var p := _panned(&"yard_drone", x)
	if p == null:
		return
	p.pitch_scale = pow(2.0, DRONE_ST / 12.0)
	p.play()
	_winding.append([p, Time.get_ticks_msec()])
	_taped(&"yard_drone")


## A drone flying away: the same whir, whole.
func leave(x: float) -> void:
	var p := _panned(&"yard_drone", x)
	if p == null:
		return
	p.pitch_scale = pow(2.0, DRONE_ST / 12.0)
	p.play()
	_taped(&"yard_drone")


## A service's work landing on the hull: one of its kept takes, never the same
## twice running, 0.15 s after the drone dips.
func work(i: int, x: float) -> void:
	var mix: Array = WORK.get(i, [])
	if mix.is_empty():
		return
	var pool: Array = mix.filter(func(n: StringName) -> bool: return n != _last_work.get(i, &"")) if mix.size() > 1 else mix
	var name: StringName = pool[randi() % pool.size()]
	_last_work[i] = name
	get_tree().create_timer(0.15).timeout.connect(func() -> void:
		var p := _panned(name, x)
		if p != null:
			p.play()
			_taped(name))


func _process(_delta: float) -> void:
	# the drones braking: pitch and level fall with them, then out at 1.6 s
	var keep: Array = []
	var r0 := pow(2.0, DRONE_ST / 12.0)
	var wd := WIND_DOWN
	var pe := 1.0 - 0.4 * wd
	var ge := 1.0 - 0.7 * wd
	for w: Array in _winding:
		var p: AudioStreamPlayer = w[0]
		var tau := float(Time.get_ticks_msec() - int(w[1])) / 1000.0
		if tau >= 1.6 or not is_instance_valid(p):
			if is_instance_valid(p):
				p.stop()
			continue
		keep.append(w)
		var u := minf(1.0, tau / 1.5)
		var v := pow(1.0 - u, 1.0 + wd)
		p.pitch_scale = r0 * (pe + (1.0 - pe) * v)
		var g := (ge + (1.0 - ge) * v) if tau <= 1.5 else ge * (1.0 - (tau - 1.5) / 0.1)
		p.volume_db = linear_to_db(maxf(g, 0.0001))
	_winding = keep
	# LEAVING THE DECK TAKES THE YARD'S SOUND WITH IT, faded rather than cut
	var vis := scene != null and scene.is_visible_in_tree()
	if _was_visible and not vis:
		_hush()
	_was_visible = vis


func _hush() -> void:
	_bed_on = false
	if _bed.playing:
		if _bed_fade != null and _bed_fade.is_valid():
			_bed_fade.kill()
		_bed_fade = create_tween()
		_bed_fade.tween_property(_bed, ^"volume_db", -60.0, 0.3)
		_bed_fade.tween_callback(_bed.stop)
	for p: AudioStreamPlayer in _voices + _pan + [_weld]:
		if p.playing:
			var t := create_tween()
			t.tween_property(p, ^"volume_db", -40.0, 0.12)
			t.tween_callback(p.stop)
	_weld_was = false
	_winding.clear()
	var names: Array[StringName] = []
	for e: Array in POWER_ON_SOUNDS.get(scene.level, []):
		if not names.has(e[1]):
			names.append(e[1])
	Audio.hush(names)
