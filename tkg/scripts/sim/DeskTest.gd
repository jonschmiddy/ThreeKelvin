extends Harness

## The science desk's rules, headless: the page's timeline both ways, each sound once at its moment
## (and none on a jump), the quit sound's click where the screen goes dark, the bake, and DESK 1's
## power-on beats in the page's order. The look is `-- sheet=DeskRooms` against the page's frames.
## Why: docs/why/DeskScene.md#the-plan

const FPS := 60.0

var _tree: SceneTree


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame
	_timeline()
	_sounds()
	await _audio_node()
	_bake()
	_beats()
	verdict("desktest")
	_tree.quit(1 if _fails > 0 else 0)


func _near(a: float, b: float, eps: float = 1e-6) -> bool:
	return absf(a - b) <= eps


func _timeline() -> void:
	var T := DeskTimeline
	_ok("act 1 ends at %.1f s real on scene %.1f" % [T.ZOOM_S, T.A], _near(T.forward(T.ZOOM_S), T.A) and _near(T.forward(0.0), 0.0))
	var pk := T.ZOOM_S + (T.KNEE - T.A) / T.SPEED
	_ok("the power-on runs %.2fx and idles at real speed from scene %.0f" % [T.SPEED, T.KNEE],
		_near(T.forward(pk), T.KNEE) and _near(T.forward(pk + 5.0), T.KNEE + 5.0) and _near(T.forward(4.9), T.A + 2.0 * T.SPEED))
	var up := true
	var prev := -1.0
	for k in 1800:
		var s := T.forward(k / FPS)
		up = up and s > prev
		prev = s
	_ok("forward only ever moves forward", up)
	var from := 11.8
	var ln := T.leave_length(from)
	var down := true
	prev = from + 1.0
	for k in int(ln * FPS) + 2:
		var s := T.leaving(k / FPS, from)
		down = down and s <= prev
		prev = s
	_ok("leaving from %.1f takes %.2f s and only runs back" % [from, ln], down and _near(T.leaving(ln, from), 0.0, 1e-4)
		and _near(T.leaving(0.0, from), from))
	_ok("leaving powers off %.1fx fast, then the zoom over %.1f s" % [T.OFF_SPEED, T.ZOOM_OUT_S],
		_near(T.leaving(1.0, from), from - T.OFF_SPEED) and _near(ln, (from - T.A) / T.OFF_SPEED + T.ZOOM_OUT_S))
	_ok("a leave inside act 1 only runs the zoom back", _near(T.leave_length(1.0), T.ZOOM_OUT_S / T.A))


## Every sound a run of frames fires: [name, value, ts].
func _play(from_real: float, to_real: float, leave_from: float = -1.0) -> Array:
	var out: Array = []
	var p := -1.0
	var off := false
	var k := 0
	while true:
		var e := k / FPS
		var ts := 0.0
		if leave_from >= 0.0:
			ts = DeskTimeline.leaving(e, leave_from)
		else:
			ts = DeskTimeline.forward(from_real + e)
		for ev: Array in DeskTimeline.sound_events(p, ts, leave_from >= 0.0, DeskOne.LAMP_AT, DeskOne.CRT_AT, off):
			out.append([ev[0], ev[1], ts, e])
			if ev[0] == &"power_off":
				off = true
		p = ts
		k += 1
		if (leave_from >= 0.0 and ts <= 0.0) or (leave_from < 0.0 and from_real + e > to_real):
			break
	return out


func _names(evs: Array) -> String:
	return " ".join(PackedStringArray(evs.map(func(e: Array) -> String: return String(e[0]))))


func _sounds() -> void:
	var fw := _play(0.0, 30.0)
	_ok("forward: the lamp, G, then the hum's warm-up, once each (%s)" % _names(fw), _names(fw) == "lamp poweron hum_warm")
	if fw.size() == 3:
		_ok("each on its moment (lamp %.3f, G %.3f, hum %.3f)" % [fw[0][2], fw[1][2], fw[2][2]],
			fw[0][2] >= DeskOne.LAMP_AT and fw[0][2] - DeskOne.LAMP_AT < 1.0 / FPS * DeskTimeline.SPEED + 1e-6
			and fw[1][2] >= DeskOne.CRT_AT and fw[2][2] >= DeskTimeline.hum_at(DeskOne.CRT_AT))
		var hum_real: float = fw[2][3] - fw[1][3]
		_ok("the hum starts %.2f s real after G (G's thunk decays at %.2f)" % [hum_real, DeskTimeline.HUM_AT], absf(hum_real - DeskTimeline.HUM_AT) < 2.0 / FPS)
	var late := _play(9.0, 30.0)
	_ok("entering a room past its moments fires nothing (%s)" % _names(late), late.is_empty())
	var jump := DeskTimeline.sound_events(3.0, 5.5, false, DeskOne.LAMP_AT, DeskOne.CRT_AT, false)
	_ok("a jump of the clock fires nothing", jump.is_empty())
	var lv := _play(0.0, 0.0, DeskOne.DONE_AT)
	_ok("leaving: the quit sound, then the lamp's click (%s)" % _names(lv), _names(lv) == "power_off lamp")
	if lv.size() == 2:
		# its click lands, OFF_CUT into the file, when the clock crosses the CRT's time
		var click_e: float = lv[0][3] + (DeskTimeline.OFF_CUT - float(lv[0][1]))
		var cross_e := (DeskOne.DONE_AT - DeskOne.CRT_AT) / DeskTimeline.OFF_SPEED
		_ok("the quit sound's click lands as the screen goes dark (%.3f s vs %.3f s)" % [click_e, cross_e], absf(click_e - cross_e) < 1.5 / FPS)
		_ok("from the power-on's end it starts at the top of the file (%.3f s in)" % float(lv[0][1]), float(lv[0][1]) < 1.0 / FPS)
	var short := _play(0.0, 0.0, 6.0)
	_ok("a leave close to the screen's time starts the quit sound part way in (%.2f s in)" % (float(short[0][1]) if not short.is_empty() else -1.0),
		not short.is_empty() and short[0][0] == &"power_off" and float(short[0][1]) > 0.5)
	var early := _play(0.0, 0.0, 4.0)
	_ok("a leave before the screen came on: the lamp's click alone (%s)" % _names(early), _names(early) == "lamp")


## The real player node, ticked frame by frame on a fixed step: the same sounds, in order.
func _audio_node() -> void:
	var a := DeskAudio.new()
	_tree.root.add_child(a)
	await _tree.process_frame
	Audio.taping = true
	Audio.tape.clear()
	var dt := 1.0 / FPS
	for k in int(14.0 * FPS):
		a.tick(DeskTimeline.forward(k * dt), dt, false)
	var from := DeskOne.DONE_AT
	for k in int(DeskTimeline.leave_length(from) * FPS) + 2:
		a.tick(DeskTimeline.leaving(k * dt, from), dt, true)
	var names := " ".join(PackedStringArray(a.fired.map(func(e: Array) -> String: return String(e[0]))))
	_ok("DeskAudio fires lamp, G, the hum, the quit sound and the lamp, once each (%s)" % names,
		names == "lamp poweron hum_warm power_off lamp")
	var taped := " ".join(PackedStringArray(Audio.tape.map(func(e: Array) -> String: return String(e[0]))))
	_ok("the clicks go through Audio: desk_lamp, desk_poweron, power_off, desk_lamp (%s)" % taped,
		taped == "desk_lamp desk_poweron power_off desk_lamp")
	Audio.taping = false
	a.stop()
	a.queue_free()


func _bake() -> void:
	var m := DeskRoom.load_meta("desk_1")
	_ok("DESK 1's bake is in the game (meta.json)", not m.is_empty())
	if m.is_empty():
		return
	_ok("its fourteen string bulbs, no pixel lit by more than four (%d, %d over)" % [int(m.smallCount), int(m.smallOver)],
		int(m.smallCount) == 14 and int(m.smallOver) == 0)
	_ok("the tube's fit scale is the page's (%.6f)" % float(m.tubeScale), float(m.tubeScale) > 1.0 and float(m.tubeScale) < 1.01)
	var role := DeskRoom.plane("desk_1", "role", DeskRoom.ART, Image.FORMAT_RF).get_image()
	var glass := 0
	for y in DeskRoom.ART.y:
		for x in DeskRoom.ART.x:
			if int(role.get_pixel(x, y).r + 0.5) == DeskRoom.ROLE_GLASS:
				glass += 1
	_ok("the glass is the page's 150 x 140 (%d px)" % glass, glass == 150 * 140)
	var a2c := DeskRoom.plane("desk_1", "a2c", DeskRoom.ART, Image.FORMAT_RGBAF).get_image()
	_ok("the art plane decodes at 384 x 216", a2c.get_size() == DeskRoom.ART and a2c.get_pixel(100, 100).r > 0.0)


## DESK 1's beats in the page's order: the lamp strikes, the strings come on in turn, the CRT's
## dot, line, raster, boot text, title and picture; leaving squeezes it back down to a dot.
func _beats() -> void:
	var life := DeskOne.new(DeskRoom.load_meta("desk_1"))
	var lit_at := -1.0
	var phases: Array[int] = []
	var strings_on: Array[int] = []
	for k in int(12.0 * 20.0):
		var ts := DeskTimeline.A + k / 20.0
		var u := life.frame(ts, DeskTimeline.forward(0.0) + ts, false)
		if lit_at < 0.0 and (u[&"w_big"] as Vector3).x > 0.0:
			lit_at = ts
		var ph: int = u[&"g_phase"]
		if phases.is_empty() or phases[phases.size() - 1] != ph:
			phases.append(ph)
		var n := 0
		for v: float in u[&"str_v"]:
			n += 1 if v > 0.0 else 0
		strings_on.append(n)
	_ok("the lamp strikes at the click (scene %.2f)" % lit_at, lit_at >= DeskOne.LAMP_AT - 0.05 and lit_at < DeskOne.LAMP_AT + 0.1)
	_ok("the CRT runs dot, line, raster, boot, title, picture (%s)" % str(phases), phases == ([0, 1, 2, 3, 4, 7, 5] as Array[int]))
	var climbs := true
	var dips := 0
	for k in range(1, strings_on.size()):
		if strings_on[k] < strings_on[k - 1]:
			dips += 1
	climbs = strings_on[strings_on.size() - 1] == 14 and dips <= 2
	_ok("the strings come on in turn, all fourteen (one catches on its second try; %d dips)" % dips, climbs)
	var off: Array[int] = []
	for k in 60:
		var ts := DeskOne.DONE_AT - k * 0.15
		var ph: int = life.frame(ts, 40.0 + k * 0.07, true)[&"g_phase"]
		if off.is_empty() or off[off.size() - 1] != ph:
			off.append(ph)
	_ok("leaving: picture, squeeze, line, dot, dark (%s)" % str(off), off == ([5, 6, 2, 1, 0] as Array[int]))
	# leaving, the lamp holds full until its click, then an afterglow of AFTER scene seconds
	life.frame(DeskOne.DONE_AT, 30.0, false)
	var held := true
	var out_at := -1.0
	for k in 200:
		var ts := DeskOne.DONE_AT - k * 0.05
		var w: float = (life.frame(ts, 50.0 + k * 0.02, true)[&"w_big"] as Vector3).x
		if ts >= DeskOne.LAMP_AT and w < 1.29:
			held = false
		if out_at < 0.0 and w <= 0.0:
			out_at = ts
	_ok("leaving, the lamp burns full down to its click", held)
	_ok("then goes out within its afterglow (dark at scene %.2f, the click at %.2f)" % [out_at, DeskOne.LAMP_AT],
		out_at < DeskOne.LAMP_AT and out_at >= DeskOne.LAMP_AT - DeskOne.AFTER - 0.05)
