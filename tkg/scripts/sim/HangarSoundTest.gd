extends Node

## THE HANGARS' SOUND against their life (Jon's Nov 25 picks): each room shown on the real hull pick for a
## full cycle; every sound start (id, time, x, gain) against the frame its life event shows, the two-crew
## limit, Old's flicker and buzz on the lamp, and silence while a room is not shown. `red=1` moves the
## door's sound off its door, to prove the check catches a wrong mapping. `docs/tests.md` has the row.
## Why: docs/why/HangarSound.md#the-test

const KF := preload("res://scripts/ui/ShipRoomKorvanFilm.gd")
const SC := preload("res://scripts/ui/ShipRoomSolariCycle.gd")
## A sound lands within one frame of its action (the test runs at --fixed-fps 60).
const FRAME := 1.0 / 60.0 + 0.002

var _tree: SceneTree
var h := Harness.new()
var _history_was := ""
var _red := false


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tree = get_tree()
	_red = Harness.arg("red") == "1"
	await Harness.frames(_tree, 2)
	_history_was = RunHistory.path
	RunHistory.path = TestRun.scratch("hangarsound_history", "json")
	var f := FileAccess.open(RunHistory.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": RunHistory.VERSION, "runs": []}))
	f.close()
	HangarSound.record = true
	Router.new_run(4242)
	await Harness.frames(_tree, 6)
	var cs := Router.current as ChassisSelect
	if not _ok("NEW RUN opens the hull pick", cs != null and cs._yard.ready_hall):
		return _finish()
	var hs := HangarSound.shared()
	_ok("the hull pick has no room tone; Korvan's depot is the hangar playing", Router._room_for(cs) == &""
		and hs.room == cs._yard.room and hs.room.id == &"korvan")
	if _red:
		for c in hs.plan.cues:
			if c.id == &"door.open":
				c.at += 0.3
	await _room(cs, &"korvan")
	cs._yard.show_set(&"solari", true, 0)
	await _room(cs, &"solari")
	cs._yard.show_set(&"calyx", false, 0)
	await _room(cs, &"old")
	await _hidden(cs)
	_finish()


# ------------------------------------------------------------------ one room, a cycle and a second
func _room(cs: ChassisSelect, id: StringName) -> void:
	var hs := HangarSound.shared()
	var r := cs._yard.room
	if not _ok("%s: the hangar plays the room on show" % id, r.id == id and hs.room == r):
		return
	print("  %s: its plan took %.1f ms (%d cues, %d layers)" % [id, hs.build_ms, hs.plan.cues.size(), hs.plan.layers.size()])
	var t_show := r.t
	var n0 := hs.starts.size()
	var watch := _watchers(r)
	var was: Dictionary[int, PackedByteArray] = {}
	var acts: Array[Array] = []
	var speeds: Array[Vector2] = []
	var crew_max := 0
	var buzz_bad := 0
	var buzz_n := 0
	var dust_bad := 0
	var dark_n := 0
	var dust_n := 0
	var loop := hs.plan.loop
	while r.t - t_show < loop + 1.0:
		await _tree.process_frame
		var t := r.t
		for wi in watch.size():
			var w: Array = watch[wi]
			var on: PackedByteArray = w[1].call(t)
			var prev: PackedByteArray = was.get(wi, PackedByteArray())
			for i in on.size():
				if on[i] == 1 and (prev.size() <= i or prev[i] == 0) and t - t_show > 0.5:
					acts.append([w[0], t])
			was[wi] = on
		if id == &"korvan":
			var cr := KF.crane(_kf(t))
			speeds.append(Vector2(t, absf(cr.vel)))
		crew_max = maxi(crew_max, hs.crew_allowed())
		if id == &"old":
			var b := _buzz(hs)
			if b != null and t - t_show > 0.1:
				buzz_n += 1
				var out := (r as ShipRoomOld).level() <= 0.0
				if (out and b.level > 0.0) or (not out and b.level < 1.0):
					buzz_bad += 1
			var ro := r as ShipRoomOld
			var dark := ro.level() <= 0.0
			dark_n += 1 if dark else 0
			dust_n += 1
			if ro.motes.size() != 2 or ro.motes.any(func(c: CanvasItem) -> bool: return c.visible == dark):
				dust_bad += 1
	if id == &"korvan":
		_brakes(speeds, t_show, acts)
	var got := hs.starts.slice(n0)
	_match(id, acts, got, t_show)
	_ok("%s: at most two crew sounds at once (most let through: %d)" % [id, crew_max], crew_max <= 2)
	if id == &"old":
		_ok("old: the buzz is cut through every out and back with the light (%d of %d frames wrong)" % [buzz_bad, buzz_n],
			buzz_n > 0 and buzz_bad == 0)
		_ok("old: no dust drawn on a dark frame, and the dust shown on a lit one (%d of %d frames wrong, %d dark)"
			% [dust_bad, dust_n, dark_n], dark_n > 0 and dust_bad == 0)
		var b := _buzz(hs)
		_ok("old: the buzz runs at the lamp's place in its three cycles (%.3f s in, room %.3f)"
			% [b.pos0 if b else -1.0, fposmod(b.t0, 30.0) if b else -1.0],
			b != null and absf(b.pos0 - fposmod(b.t0, 30.0)) < 0.002)
	_print_starts(got)
	_baked(r)


## The baked cues are the ones the room's life gives now (a changed life fails here until they are rebaked).
func _baked(r: ShipRoom) -> void:
	var us := Time.get_ticks_usec()
	var want := HangarCues.compute(r).cues
	var d := HangarCues.diff(want, HangarCues.baked(r.id))
	_ok("%s: the baked cues are its life's (%d, worked out in %.1f ms)%s" % [r.id, want.size(),
		(Time.get_ticks_usec() - us) / 1000.0, "" if d == "" else ": DIFFER at %s; rebake: %s" % [d, HangarCues.REBAKE]],
		d == "" and not want.is_empty())


func _buzz(hs: HangarSound) -> HangarSound.Voice:
	for v in hs._voices:
		if v.busy and v.id == &"lamp.buzz" and v.rate >= 0.0:
			return v
	return null


## Each life event the room shows, by the test's own reading of its life: [id, on(t) -> one flag per instance].
func _watchers(r: ShipRoom) -> Array[Array]:
	match r.id:
		&"korvan":
			return _korvan_watch(r as ShipRoomKorvan)
		&"solari":
			return _solari_watch()
		_:
			return _old_watch()


static func _kf(t: float) -> float:
	return float(KF.pyround(t * 30.0) % KF.NF) / 30.0


static func _one(b: bool) -> PackedByteArray:
	return PackedByteArray([1 if b else 0])


func _korvan_watch(r: ShipRoomKorvan) -> Array[Array]:
	var opening := func(t: float) -> float: return KF.opening(KF.win(_kf(t), KF.DOOR_AT))
	var burn := func(t: float) -> bool: return KF.burn(KF.win(_kf(t), KF.ENGINE_AT)) > 0.0
	var out: Array[Array] = [
		[&"door.open", func(t: float) -> PackedByteArray: return _one(float(opening.call(t)) > 0.0)],
		[&"door.close", func(t: float) -> PackedByteArray:
			return _one(float(opening.call(t)) < 1.0 and float(opening.call(t)) > 0.0 and float(opening.call(t - 1.0)) >= 1.0)],
		[&"engine.spool", func(t: float) -> PackedByteArray: return _one(bool(burn.call(t)))],
		[&"lamps.sag", func(t: float) -> PackedByteArray: return _one(bool(burn.call(t)) and float(r._light.u[&"lk"]) < 0.99)],
		[&"crew.weld.lift", func(t: float) -> PackedByteArray: return _one(KF.weld_pose(fposmod(_kf(t), 10.0)).y == 1)],
		[&"crew.grind.bench", func(t: float) -> PackedByteArray: return _one(KF.in_any(_kf(t), KF.GRIND))],
		[&"crew.crate.set", func(t: float) -> PackedByteArray:
			var cs := r.front.crates_at(fposmod(_kf(t), 30.0))
			var tc := KF.win(_kf(t), KF.DOOR_AT)
			var s := PackedByteArray([0, 0, 1 if tc >= 8.6 else 0])
			for i in cs.size():
				s[i] = 1 if cs[i].z < 0.5 and _carried(r, i, t) else 0
			return s],
	]
	for sp: Dictionary in KF.K["weld8"]:
		var idn := &"crew.grind.ladder" if sp["kind"] == "grind" else &"crew.weld.ladder"
		out.append([idn, func(t: float) -> PackedByteArray: return _one(KF.weld_state(sp, _kf(t)).y > 0.5)])
	return out


## Was crate i carried within the last third of a second (a set-down, not one that was always resting)?
func _carried(r: ShipRoomKorvan, i: int, t: float) -> bool:
	for k in range(1, 11):
		var cs := r.front.crates_at(fposmod(_kf(t - k / 30.0), 30.0))
		if cs.size() > i and cs[i].z > 0.5:
			return true
	return false


## The crane's brake: the frame it is slowest on each 15 s pass.
func _brakes(speeds: Array[Vector2], t_show: float, acts: Array[Array]) -> void:
	for pass_i in 2:
		var best := Vector2(-1, INF)
		for s in speeds:
			var u := fposmod(_kf(s.x), 30.0) - pass_i * 15.0
			if u >= 2.0 and u < 13.0 and s.y < best.y - 0.003 and s.x - t_show > 0.5:
				best = s
		if best.x >= 0.0:
			acts.append([&"crane.brake", best.x])


func _solari_watch() -> Array[Array]:
	var out: Array[Array] = [
		[&"roar.furnace2", func(t: float) -> PackedByteArray: return _one(SC.roar_k(t) > 0.0)],
		[&"crew.weld.lift", func(t: float) -> PackedByteArray: return _one(ShipRoomSolariCrew.weld_state(t)[1] == 1)],
		[&"crew.grind.fettler", func(t: float) -> PackedByteArray: return _one(ShipRoomSolariCrew.grind_on(t))],
	]
	for j in 6:
		out.append([StringName("pour.tap%d" % (j + 1)), func(t: float) -> PackedByteArray:
			return _one(SC.u_of(j, t) >= SC.FALL and SC.u_of(j, t) < SC.P_DUR)])
		if SC.stack_x(j) < 0:
			continue
		out.append([&"crew.plate.set", func(t: float) -> PackedByteArray: return _one(not SC.jib_state(SC.u_of(j, t)).carry)])
		out.append([&"crew.jib.chain", func(t: float) -> PackedByteArray:
			var u := SC.u_of(j, t)
			var s := PackedByteArray()
			for key: String in ["down", "lift", "lower", "up"]:
				var ab: Vector2 = SC.JIB[key]
				s.append(1 if u >= ab.x and u < ab.y else 0)
			return s])
		out.append([&"crew.trolley.roll", func(t: float) -> PackedByteArray:
			var s := PackedByteArray()
			for lap in 2:
				var ue := SC.u_of(j, t) + 30.0 * lap
				var a := ShipRoomSolariCrew.trolley_at(j, ue)
				var b := ShipRoomSolariCrew.trolley_at(j, ue - 1.0 / 60.0)
				s.append(1 if not is_nan(a) and not is_nan(b) and a != b and _still_before(j, ue) else 0)
			return s])
	return out


## Had bay j's trolley stood still for half a second before `ue` (so this is a roll starting, not a step)?
static func _still_before(j: int, ue: float) -> bool:
	var x := ShipRoomSolariCrew.trolley_at(j, ue - 1.0 / 60.0)
	for k in range(2, 31):
		var y := ShipRoomSolariCrew.trolley_at(j, ue - k / 60.0)
		if not is_nan(y) and not is_nan(x) and y != x:
			return false
	return true


func _old_watch() -> Array[Array]:
	var step := func(t: float) -> float: return ShipRoomOld.lamp_step(fmod(t, ShipRoomOld.LOOP))
	var after_out := func(t: float) -> bool:
		for o: Array in ShipRoomOld.OFFS:
			var e := float(o[0]) + float(o[1])
			var u := fmod(t, ShipRoomOld.LOOP)
			if u >= e and u < e + 0.02:
				return true
		return false
	return [
		[&"flick.out", func(t: float) -> PackedByteArray: return _one(float(step.call(t)) <= 0.0)],
		[&"lamp.die.short", func(t: float) -> PackedByteArray: return _one(float(step.call(t)) <= 0.0 and fmod(t, 10.0) < 4.0)],
		[&"lamp.die", func(t: float) -> PackedByteArray: return _one(float(step.call(t)) <= 0.0 and fmod(t, 10.0) >= 4.0)],
		[&"flick.back", func(t: float) -> PackedByteArray: return _one(float(step.call(t)) > 0.5 and bool(after_out.call(t)))],
		[&"flick.dip", func(t: float) -> PackedByteArray:
			var s := float(step.call(t))
			return _one(s > 0.0 and s < 1.0)],
	]


# ------------------------------------------------------------------ matching sounds to their actions
## Every action has its sound landing within one frame (a crew shot may be held back by the two-crew rule),
## and every sound has its action.
func _match(id: StringName, acts: Array[Array], got: Array[Dictionary], t_show: float) -> void:
	var used: Dictionary[int, bool] = {}
	var missed: Array[String] = []
	var worst := 0.0
	for a: Array in acts:
		var best := -1
		var err := INF
		for i in got.size():
			var g := got[i]
			if used.has(i) or g["id"] != a[0]:
				continue
			var e := absf(float(g["t"]) + float(g["lead"]) - float(a[1]))
			if e < err:
				err = e
				best = i
		if best >= 0 and err <= FRAME:
			used[best] = true
			worst = maxf(worst, err)
		else:
			missed.append("%s at %.3f (nearest %.3f s off)" % [a[0], fposmod(float(a[1]), HangarSound.shared().plan.loop), err])
	var stray: Array[String] = []
	for i in got.size():
		var g := got[i]
		if used.has(i) or float(g["t"]) - t_show < 0.6 or g["id"] == &"lamp.buzz":
			continue
		stray.append("%s at %.3f" % [g["id"], fposmod(float(g["t"]), HangarSound.shared().plan.loop)])
	_ok("%s: each of %d life events has its sound within one frame (worst %.1f ms)%s" % [id, acts.size(), worst * 1000.0,
		"" if missed.is_empty() else ": MISSED " + ", ".join(missed.slice(0, 6))], missed.is_empty() and acts.size() > 0)
	_ok("%s: and every sound has its event (%d sounds)%s" % [id, got.size(),
		"" if stray.is_empty() else ": STRAY " + ", ".join(stray.slice(0, 6))], stray.is_empty())


func _print_starts(got: Array[Dictionary]) -> void:
	var by: Dictionary[StringName, int] = {}
	for g in got:
		by[g["id"]] = by.get(g["id"], 0) + 1
	for k: StringName in by:
		var g0: Dictionary = got[got.find_custom(func(g: Dictionary) -> bool: return g["id"] == k)]
		print("  %-20s x%-3d first at %6.3f lands +%.3f  x %5.0f  gain %+5.1f dB  %s%s" % [k, by[k],
			fposmod(float(g0["t"]), HangarSound.shared().plan.loop), float(g0["lead"]), float(g0["x"]), float(g0["gain"]),
			g0["file"], "  (held back)" if g0.get("skipped", false) else ""])


# ------------------------------------------------------------------ no sound while a room is not shown
func _hidden(cs: ChassisSelect) -> void:
	var hs := HangarSound.shared()
	var old_room := cs._yard.room
	cs._yard.show_set(&"korvan", true, 0)
	await Harness.frames(_tree, 2)
	var n0 := hs.starts.size()
	await _wait(0.4)
	var stale := hs.starts.slice(n0).filter(func(g: Dictionary) -> bool: return g["room"] != &"korvan")
	_ok("a room left plays nothing more (%d of its sounds started after)" % stale.size(), stale.is_empty()
		and old_room != cs._yard.room)
	_ok("and its voices are out within 0.4 s (%d still on)" % _others(hs, cs._yard.room), _others(hs, cs._yard.room) == 0)
	cs.visible = false
	await Harness.frames(_tree, 2)
	var n1 := hs.starts.size()
	await _wait(3.0)
	_ok("the hull pick hidden starts nothing for 3 s (%d started)" % (hs.starts.size() - n1), hs.starts.size() == n1)
	_ok("and every voice is out (%d busy)" % _busy(hs), _busy(hs) == 0)
	cs.visible = true
	await _wait(2.0)
	_ok("shown again, it plays again (%d started)" % (hs.starts.size() - n1), hs.starts.size() > n1)
	Router.show_launcher()
	await _wait(0.5)
	_ok("leaving the hull pick leaves the hangar silent (%d busy, room %s)" % [_busy(hs), hs.room],
		_busy(hs) == 0 and hs.room == null)


func _wait(secs: float) -> void:
	var t0 := GameClock.now()
	while GameClock.now() - t0 < secs:
		await _tree.process_frame


func _busy(hs: HangarSound) -> int:
	return hs._voices.filter(func(v: HangarSound.Voice) -> bool: return v.busy).size()


## Busy voices that are not the room on show's (a cue or layer it does not have).
func _others(hs: HangarSound, r: ShipRoom) -> int:
	var n := 0
	for v in hs._voices:
		if v.busy and (v.rate < 0.0 or (v.cue != null and not hs.plan.cues.has(v.cue))):
			n += 1
	return n if r != null else -1


func _finish() -> void:
	HangarSound.record = false
	if _history_was != "":
		RunHistory.clear()
		RunHistory.path = _history_was
	h.verdict("hangarsoundtest")
	_tree.quit(h.code())
