extends Node

## The sector map's ship, flown as a player would and filmed with its sound:
##   godot --path . --write-movie <out.avi> --fixed-fps 30 -- sheet=FlightClip [seed=N]
## Starts a run on the real shell and router, jumps to a system, then on a fixed
## timeline: the ship leaves the edge and steers at the first world -- thrusting
## until the dotted line says it will slide into orbit, then letting go -- and
## the ring takes it; it sits in orbit, W leaves along it; the arrows pan the
## view and a drag pans it back; a world is selected with one click and flown to
## with a second, on a transfer orbit, ending in orbit; a click on empty space
## goes back to the list, and the wheel zooms in. Quits at the end. `nova=S`
## forces a distant supernova S seconds in, somewhere clear in the far sky.
## `loc` turns LOCATION on first (zoom 2, the ship held in the middle); `log=<json>`
## writes every frame's ship -- its mode, whether it is burning onto an orbit,
## its heading, where it is drawn on the map, its plane position -- to measure
## how smooth it moves.
## `tour` flies the auto-flights instead: in orbit of the first world, the next
## world selected (its whole flight drawn dotted) and flown to, then the star's
## close orbit, then a station, belt, hulk or contact if the system has one --
## each leg once the last is on its orbit, the plan shown a second and a half
## first. Quits when the tour is done.
##   godot --path . -- sheet=FlightClip tape=<wav> [tapesecs=S]
## Records the thrust instead, heard as a player hears it: W held from the edge
## for S seconds (6), the SFX bus drained from an AudioEffectCapture every frame
## (as StationShot's `boardav`) into a 16-bit wav at the mix rate, front pair only.
## Silent for the first second; `tapepulse=ON,OFF` presses and lets go of W on
## that rhythm instead of holding it, to hear the presses.
## `tapesession` plays a player's minute instead, through real key events (so
## every listener hears them): W taps from 50 ms to 2 s holds, quick repeats, A,
## D and S, LOCATION on and off, a world selected and flown to (its insertion),
## leaving its orbit with W, the wheel -- on the master bus with the music and
## the room tone muted, and every sound Audio plays logged by name and time
## (`<wav>.json`, with the key events).

const END := 34.0

var _t := 0.0
var _scr
var _steps: Array = []
## The world the ship is steered at, while it is (-9 when the keys are left alone).
var _steer := -9
## `tape=`: where the thrust recording goes, and for how long W is held.
var _tape := ""
var _tape_secs := 6.0
var _cap: AudioEffectCapture = null
var _pcm := PackedVector2Array()
var _tape_t0 := -1.0
var _pulse := Vector2.ZERO
var _session := false
var _tour: Array = []
var _tour_at := -1.0
var _tour_leg := -9
var _touring := false
var _tape_ms := 0
var _sess: Array = []
var _keylog: Array = []
var _log := ""
var _rows: Array = []


func _ready() -> void:
	Rng.forced = 4242
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("seed="):
			Rng.forced = int((a as String).substr(5))
		elif (a as String).begins_with("tape="):
			_tape = (a as String).substr(5)
		elif a == "tapesession":
			_session = true
		elif (a as String).begins_with("log="):
			_log = (a as String).substr(4)
		elif (a as String).begins_with("tapepulse="):
			var pp := (a as String).substr(10).split(",")
			_pulse = Vector2(float(pp[0]), float(pp[1]))
		elif (a as String).begins_with("tapesecs="):
			_tape_secs = float((a as String).substr(9))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.index != Run.at and Run.can_jump_to(m) and m.type == MapGen.NodeType.SYSTEM:
			Router.commit_jump(m.index)
			break


func _process(delta: float) -> void:
	_t += delta
	if _scr == null:
		if Router.current is SystemMapScreen and Router.current.view.layout != null and Router.current.flight != null:
			_scr = Router.current
			_scr.harness_keys = true
			if _tape == "" and not "tour" in OS.get_cmdline_user_args():
				_plan()
			if "loc" in OS.get_cmdline_user_args():
				_scr._on_location()
			if "tour" in OS.get_cmdline_user_args():
				_tour_plan()
		return
	if _touring:
		_tour_step()
		if _log == "":
			return
	if _log != "":
		var fl = _scr.flight
		var w3: Vector3 = fl.where3()
		# where it is drawn on the map, before the rounding to whole pixels
		var ov = _scr.overlay
		var drawn: Vector2 = Vector2(_scr.view.CX, _scr.view.CY) + ov.ship_rel()
		if ov._ok > 1.001 and ov._ok_body >= -1:
			var bw: Vector2 = ov._body_scr(ov._ok_body) - _scr.view.pan
			drawn = bw + (drawn - bw) * ov._ok
		_rows.append([_t, String(fl.mode), fl.inserting(), fl.ang, drawn.x, drawn.y, w3.x, w3.z, fl.burn, fl.burn_k, _scr.view.zoom, fl.star_orbiting(), fl.reached()])
	if _tape != "":
		_tape_step()
		return
	while not _steps.is_empty() and _t >= float(_steps[0][0]):
		var s: Array = _steps.pop_front()
		(s[1] as Callable).call()
	if _steer >= 0:
		_fly_at(_steer)
	if _t >= END:
		if _log != "":
			var fw := FileAccess.open(_log, FileAccess.WRITE)
			fw.store_string(JSON.stringify(_rows))
			fw.close()
		get_tree().quit()


## A PLAYER STEERING AT A WORLD: the nose turned where the velocity needs to
## change (straight at the world, slowing to stop at its ring), thrust when it
## points there, and let go the moment the dotted line says it will slide in.
func _fly_at(i: int) -> void:
	var fl = _scr.flight
	var keys := {"w": false, "a": false, "s": false, "d": false}
	if fl.mode == &"rail" or fl.mode == &"keep":
		if fl.orbit_body() == i:
			_steer = -9
			_scr._wasd = keys
			return
		keys.w = true
		_scr._wasd = keys
		return
	if fl.mode != &"free" and fl.mode != &"warp":
		return
	var line: Dictionary = fl.line
	if not line.is_empty() and not (line.out as Dictionary).is_empty() and int(line.out.body) == i:
		_scr._wasd = keys
		return
	var c: Vector3 = fl.center(i, _scr.view.t)
	var d := Vector2(c.x - fl.f.p.x, c.z - fl.f.p.y)
	var dist := d.length()
	var want: Vector2 = d / dist * minf(130.0, sqrt(2.0 * 30.0 * maxf(0.0, dist - 20.0)) + 20.0) - fl.f.v
	var ang := atan2(want.y, want.x)
	var nose := atan2(sin(fl.f.head) / 0.38, cos(fl.f.head))
	var err := wrapf(ang - nose, -PI, PI)
	if absf(err) > 0.03:
		keys.d = err > 0.0
		keys.a = err < 0.0
	if absf(err) < 0.35 and want.length() > 6.0:
		keys.w = true
	_scr._wasd = keys


## Frame coordinates of a map point.
func _f(map_p: Vector2) -> Vector2:
	return map_p + _scr._box.position


func _move(p: Vector2, rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.relative = rel
	_scr._on_map_input(e)


func _button(b: MouseButton, p: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = b
	e.pressed = down
	e.position = p
	_scr._on_map_input(e)


func _click(p: Vector2) -> void:
	_move(p, Vector2(1, 0))
	_button(MOUSE_BUTTON_LEFT, p, true)
	_button(MOUSE_BUTTON_LEFT, p, false)


func _plan() -> void:
	var v = _scr.view
	var worlds: Array = []
	for i in v.layout.bodies.size():
		if v.layout.bodies[i].world != &"":
			worlds.append(i)
	var first: int = worlds[0] if not worlds.is_empty() else -1
	var second: int = worlds[1] if worlds.size() > 1 else -1
	var frame: Vector2 = _scr._frame.size
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("nova="):
			_steps.append([float((a as String).substr(5)), func() -> void: v.nova_now()])
	# 1 s: steer at the first world, and let the ring take it
	_steps.append([1.0, func() -> void: _steer = first])
	# 13 s: leave the orbit with W
	_steps.append([13.0, func() -> void:
		_steer = -9
		_scr._wasd = {"w": true, "a": false, "s": false, "d": false}])
	_steps.append([13.6, func() -> void: _scr._wasd = {"w": false, "a": false, "s": false, "d": false}])
	# 15 s: the arrows pan left a second; 16.6 s: a drag pans back
	_steps.append([15.0, func() -> void: _scr._arrows = Vector2.LEFT])
	_steps.append([16.0, func() -> void: _scr._arrows = Vector2.ZERO])
	var a0 := Vector2(frame.x * 0.3, frame.y * 0.6)
	_steps.append([16.6, func() -> void: _button(MOUSE_BUTTON_LEFT, a0, true)])
	for k in 30:
		var u := float(k + 1) / 30.0
		_steps.append([16.6 + u, func() -> void: _move(a0 + Vector2(-160.0 * u, 0), Vector2(-5, 0))])
	_steps.append([17.7, func() -> void: _button(MOUSE_BUTTON_LEFT, a0 + Vector2(-160, 0), false)])
	# 19 s: one click selects the second world; 21 s: a second flies there
	var target := second if second >= 0 else -1
	_steps.append([19.0, func() -> void:
		var p: Vector2 = v.origin() if target == -1 else v.at[target]
		_click(_f(p))])
	_steps.append([21.0, func() -> void:
		var p: Vector2 = v.origin() if target == -1 else v.at[target]
		_click(_f(p))])
	# 27 s: empty space, back to the list; 28.5 s: the wheel zooms in over the ship
	_steps.append([27.0, func() -> void: _click(Vector2(frame.x * 0.08, frame.y * 0.9))])
	for k in 6:
		_steps.append([28.5 + k * 0.25, func() -> void:
			_button(MOUSE_BUTTON_WHEEL_UP, _f(_scr.overlay._ship_at), true)])
	_steps.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))


## THE THRUST, RECORDED: W held, the SFX bus captured every frame, then written.
func _tape_step() -> void:
	var sfx := AudioServer.get_bus_index(&"SFX")
	if _session:
		sfx = 0
	if _cap == null:
		if _session:
			_scr.harness_keys = false
			for bn in [&"Music", &"Ambient"]:
				var bi := AudioServer.get_bus_index(bn)
				if bi >= 0:
					AudioServer.set_bus_mute(bi, true)
			Audio.tape.clear()
			Audio.taping = true
			_session_plan()
		_cap = AudioEffectCapture.new()
		_cap.buffer_length = 2.0
		AudioServer.add_bus_effect(sfx, _cap)
		_cap.clear_buffer()
		_tape_t0 = _t
		_tape_ms = Time.get_ticks_msec()
		return
	_pcm.append_array(_cap.get_buffer(_cap.get_frames_available()))
	var u := _t - _tape_t0 - 1.0
	if _session:
		while not _sess.is_empty() and u >= float(_sess[0][0]):
			var ev: Array = _sess.pop_front()
			(ev[1] as Callable).call()
	else:
		var held := u >= 0.0 and (_pulse == Vector2.ZERO or fmod(u, _pulse.x + _pulse.y) < _pulse.x)
		_scr._wasd = {"w": held, "a": false, "s": false, "d": false}
	if "tapelog" in OS.get_cmdline_user_args() and Engine.get_process_frames() % 15 == 0:
		print("  tape %.2f held %s mode %s level %.2f db %.1f" % [u, _scr._wasd.w, _scr.flight.mode, Audio._ship_level, Audio._ship_loop.volume_db if Audio._ship_loop != null else -99.0])
	if u < _tape_secs + 0.5:
		return
	_scr._wasd = {"w": false, "a": false, "s": false, "d": false}
	AudioServer.remove_bus_effect(sfx, AudioServer.get_bus_effect_count(sfx) - 1)
	# ONE 512-FRAME BLOCK PER SPEAKER PAIR on a surround output, in turn; which
	# block the capture starts on is not fixed, so the front pair is the phase
	# that carries the sound (the ship's player plays on the front pair only)
	var pairs := int(AudioServer.get_speaker_mode()) + 1
	if pairs > 1:
		var best := PackedVector2Array()
		var best_e := -1.0
		for ph in pairs:
			var front := PackedVector2Array()
			var at := ph * 512
			while at < _pcm.size():
				front.append_array(_pcm.slice(at, mini(at + 512, _pcm.size())))
				at += 512 * pairs
			var e := 0.0
			for q in front:
				e += q.length_squared()
			if e > best_e:
				best_e = e
				best = front
		_pcm = best
	var rate := int(AudioServer.get_mix_rate())
	var data := PackedByteArray()
	data.resize(_pcm.size() * 4)
	for k in _pcm.size():
		data.encode_s16(k * 4, int(clampf(_pcm[k].x, -1.0, 1.0) * 32767.0))
		data.encode_s16(k * 4 + 2, int(clampf(_pcm[k].y, -1.0, 1.0) * 32767.0))
	var w := FileAccess.open(_tape, FileAccess.WRITE)
	w.store_buffer("RIFF".to_ascii_buffer())
	w.store_32(36 + data.size())
	w.store_buffer("WAVEfmt ".to_ascii_buffer())
	w.store_32(16)
	w.store_16(1)
	w.store_16(2)
	w.store_32(rate)
	w.store_32(rate * 4)
	w.store_16(4)
	w.store_16(16)
	w.store_buffer("data".to_ascii_buffer())
	w.store_32(data.size())
	w.store_buffer(data)
	w.close()
	if _session:
		Audio.taping = false
		var t0ms := int(_tape_t0 * 1000.0)
		var jf := FileAccess.open(_tape + ".json", FileAccess.WRITE)
		jf.store_string(JSON.stringify({"keys": _keylog, "sounds": Audio.tape, "tape_start_ms": _tape_ms}))
		jf.close()
	print("tape: %.2f s at %d Hz, %d speaker pairs, to %s" % [float(_pcm.size()) / float(rate), rate, pairs, _tape])
	get_tree().quit()


## A real key, through the whole input pipeline, logged against the tape.
func _key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)
	_keylog.append([OS.get_keycode_string(code), down, Time.get_ticks_msec() - _tape_ms])


## A PLAYER'S MINUTE, as times from the tape's first second on.
func _session_plan() -> void:
	var press := func(at: float, code: Key, hold: float) -> void:
		_sess.append([at, func() -> void: _key(code, true)])
		_sess.append([at + hold, func() -> void: _key(code, false)])
	var at := 0.0
	for hold: float in [0.05, 0.1, 0.2, 0.5, 1.0, 2.0]:
		press.call(at, KEY_W, hold)
		at += hold + 0.9
	press.call(at, KEY_A, 0.6)
	press.call(at + 1.0, KEY_D, 0.6)
	press.call(at + 2.0, KEY_S, 0.8)
	at += 3.5
	for k in 5:
		press.call(at + k * 0.25, KEY_W, 0.05)
	at += 2.0
	press.call(at, KEY_L, 0.05)
	press.call(at + 0.6, KEY_W, 0.3)
	press.call(at + 1.6, KEY_W, 0.05)
	press.call(at + 2.1, KEY_W, 1.0)
	press.call(at + 3.6, KEY_L, 0.05)
	at += 4.5
	# the first world: selected, then flown to (its insertion at the end)
	var v = _scr.view
	var first := -1
	for i in v.layout.bodies.size():
		if v.layout.bodies[i].world != &"":
			first = i
			break
	_sess.append([at, func() -> void: _scr.select_body(first)])
	_sess.append([at + 1.0, func() -> void: _scr.fly_to_body(first)])
	at += 6.0
	press.call(at, KEY_W, 0.4)
	at += 2.0
	for k in 3:
		_sess.append([at + k * 0.3, func() -> void: _button(MOUSE_BUTTON_WHEEL_UP, _f(_scr.overlay._ship_at), true)])
	at += 1.5
	press.call(at, KEY_W, 0.2)
	press.call(at + 1.0, KEY_W, 0.05)
	_tape_secs = at + 3.0


## THE TOUR: its legs, and the ship put in orbit of the first world.
func _tour_plan() -> void:
	var v = _scr.view
	var worlds: Array = []
	var keeps: Array = []
	for i in v.layout.bodies.size():
		var b: SystemLayout.Body = v.layout.bodies[i]
		if b.world != &"":
			worlds.append(i)
		elif _scr.flight.is_keep(i):
			keeps.append(i)
	_scr.flight.place_at(int(worlds[0]), v.t)
	_scr._was_at = _scr.flight.reached()
	_tour = [worlds[-1] if worlds.size() > 1 else -1, -1]
	if worlds.size() > 2:
		_tour.insert(1, worlds[1])
	if not keeps.is_empty():
		_tour.append(keeps[0])
	_tour_at = _t + 1.0
	_touring = true


func _tour_step() -> void:
	var fl = _scr.flight
	if _tour_leg >= -1:
		# flying: the next leg once this one is on its orbit
		if fl.mode != &"fly" and fl.reached() == _tour_leg:
			_tour_leg = -9
			_tour_at = _t + 1.0
			if _tour.is_empty():
				_tour_at = _t + 2.0
		return
	if _t < _tour_at:
		return
	if _tour.is_empty():
		if _log != "":
			var fw := FileAccess.open(_log, FileAccess.WRITE)
			fw.store_string(JSON.stringify(_rows))
			fw.close()
		get_tree().quit()
		return
	var nxt: int = _tour[0]
	if _scr.overlay.selected != nxt:
		_scr.select_body(nxt)
		# `tourhold=S`: how long each leg's plan is shown before it is flown
		_tour_at = _t + 1.5
		for a in OS.get_cmdline_user_args():
			if (a as String).begins_with("tourhold="):
				_tour_at = _t + float((a as String).substr(9))
		return
	_tour.pop_front()
	_tour_leg = nxt
	_scr.fly_to_body(nxt)
