class_name HangarCues
extends RefCounted

## WHEN EACH HANGAR SOUND STARTS: every cue of the sound3 cue map tied to the life event it belongs to, read
## off the room's own life functions (the frame the action shows), never off the cue map's times. Levels,
## lanes and priorities are the cue map's (`tk-scratch/shipselect/sound3/out/cues.json`, Jon's A mixes).
## Why: docs/why/HangarSound.md#cues

enum Kind { SHOT, SPAN }
enum Sync { ONSET, HIT }

const KF := preload("res://scripts/ui/ShipRoomKorvanFilm.gd")
const SC := preload("res://scripts/ui/ShipRoomSolariCycle.gd")
## The mixer's hero lift per room (concept A's 4 dB, Old A's extra 5.5).
const HERO_DB := {&"korvan": 4.0, &"solari": 4.0, &"old": 9.5}
## The flicker as Jon set it: the cue map's gains + flick_1.wav's 12.2 dB over them + his 10 dB.
## Why: docs/why/HangarSound.md#flicker-and-buzz
const FLICK_DB := 12.2 + 10.0
const FLICK_GAIN := {&"dip": -10.0, &"out": -4.0, &"back": -12.0}
## The buzz: -9.8 dB vs the bed (the lamp's lane) + Jon's 10 dB.
const BUZZ_DB := -9.8 + 10.0


## One sound a room's life starts: `at` is when its action first shows on the room's clock (s into the loop).
class Cue:
	var id: StringName
	var kind := Kind.SHOT
	var at := 0.0
	## A span's end (may pass the loop's end: it wraps).
	var end := 0.0
	var x := 480.0
	var y := 300.0
	var files: Array[StringName] = []
	## dB vs the bed, the hero lift in.
	var gain := 0.0
	var hero := false
	var prio := 0
	var dark := 0.0
	var sync := Sync.ONSET
	## A pour is cut `cut` s in, faded over 0.6 s after it (the mixer's).
	var cut := 0.0
	## How long a crew shot counts against the two at once.
	var dur := 1.4
	## -1 every lap; 0 or 1 on even or odd laps only (Solari's big pour alternates).
	var lap := -1
	## Its place among the cues of its id in a lap, and how many there are (the variation's occurrence).
	var n := 0
	var per := 1
	## Extra variation key: the flicker's place in the lamp's schedule.
	var k := -1


## A steady layer: a loop under the room (bed layer, hum, buzz, a moving source).
class Layer:
	var id: StringName
	var file: StringName
	var gain := 0.0
	var dark := 0.0
	var wet := 0.0
	var x := 480.0
	var pan_k := 0.0
	## Its level 0..1 and x each frame, from the room (null: 1 and `x`).
	var level: Callable = Callable()
	var at_x: Callable = Callable()
	## Played at the room clock's place in it (the buzz, three lamp cycles long).
	var synced := false
	var crew := false


## A room's whole plan.
class Plan:
	var room: StringName
	var loop := 30.0
	var beds: Array[StringName] = []
	var seg := 15.0
	var air: StringName
	var cues: Array[Cue] = []
	var layers: Array[Layer] = []
	var hero_db := 4.0


## Each room's cues, worked out once a run: its life is the same every visit, and a banner click should not pay again.
static var _cached: Dictionary[StringName, Array] = {}


static func plan_for(r: ShipRoom) -> Plan:
	var p := Plan.new()
	p.room = r.id
	p.hero_db = float(HERO_DB.get(r.id, 4.0))
	var have: Array = _cached.get(r.id, [])
	var cues := have.is_empty()
	match r.id:
		&"korvan":
			_korvan(p, r as ShipRoomKorvan, cues)
		&"solari":
			_solari(p, r as ShipRoomSolari, cues)
		&"old":
			_old(p, r as ShipRoomOld, cues)
	if cues:
		_count(p)
		_cached[r.id] = p.cues.duplicate()
	else:
		p.cues.assign(have)
	return p


## The mixer's lanes: 0 at the front lane (row 400), 1 at the wall's foot, up to 1.4 for the decks.
static func depth_of(y: float) -> float:
	return clampf((400.0 - y) / 190.0, 0.0, 1.4)


static func _count(p: Plan) -> void:
	var seen: Dictionary[StringName, int] = {}
	p.cues.sort_custom(func(a: Cue, b: Cue) -> bool: return a.at < b.at)
	for c in p.cues:
		c.n = seen.get(c.id, 0)
		seen[c.id] = c.n + 1
	for c in p.cues:
		c.per = seen[c.id]


static func _cue(p: Plan, id: StringName, at: float, x: float, y: float, files: Array[StringName], gain: float) -> Cue:
	var c := Cue.new()
	c.id = id
	c.at = fposmod(at, p.loop)
	c.x = x
	c.y = y
	c.files = files
	c.gain = gain
	p.cues.append(c)
	return c


static func _hero(p: Plan, c: Cue) -> Cue:
	c.hero = true
	c.gain += p.hero_db
	return c


static func _span(p: Plan, id: StringName, ab: Vector2, x: float, y: float, files: Array[StringName], gain: float,
		prio: int, dark: float) -> Cue:
	var c := _cue(p, id, ab.x, x, y, files, gain)
	c.kind = Kind.SPAN
	c.end = c.at + (ab.y - ab.x)
	c.prio = prio
	c.dark = dark
	return c


# ------------------------------------------------------------------ finding the life's events
## Each instant over [0, loop) that `on` turns true: sampled every `step` (half the shortest life state, a 30 fps
## frame), then halved to a tenth of a ms.
static func edges(on: Callable, loop: float, step: float = 1.0 / 60.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(ceilf(loop / step))
	var was := bool(on.call(loop - step))
	for i in n:
		var t := i * step
		var now := bool(on.call(t))
		if now and not was:
			out.append(_refine(on, t - step, t))
		was = now
	return out


static func _refine(on: Callable, a: float, b: float) -> float:
	for i in 14:
		var m := (a + b) * 0.5
		if bool(on.call(m)):
			b = m
		else:
			a = m
	return b


## The runs over [0, loop) where `on` holds, each (start, end); one that runs over the wrap ends past `loop`.
static func spans(on: Callable, loop: float, step: float = 1.0 / 60.0) -> Array[Vector2]:
	var ups := edges(on, loop, step)
	var downs := edges(func(t: float) -> bool: return not bool(on.call(t)), loop, step)
	var out: Array[Vector2] = []
	for a in ups:
		var b := INF
		for d in downs:
			var e := d if d > a else d + loop
			b = minf(b, e)
		out.append(Vector2(a, b))
	return out


# ------------------------------------------------------------------ Korvan's Parts depot (mix18 on a 30 s clock)
## The life draws film frame pyround(t x 30): a state at room time t is the state at that frame.
static func _kf(t: float) -> float:
	return float(KF.pyround(t * 30.0) % KF.NF) / 30.0


static func _korvan(p: Plan, r: ShipRoomKorvan, cues: bool) -> void:
	KF.ensure()
	p.loop = KF.T
	p.beds.assign([&"k_bed_1", &"k_bed_2"])
	p.seg = 15.0
	p.air = &"k_air_1"
	_korvan_moves(p)
	if cues:
		_korvan_shots(p)
		_korvan_crew(p, r)


static func _korvan_shots(p: Plan) -> void:
	var crane: Array[StringName] = [&"k_crane_1", &"k_crane_2"]
	var door: Array[StringName] = [&"k_door_1", &"k_door_2"]
	# the crane brakes mid hall on each 15 s pass: the first frame it is at its slowest (two frames tie)
	var xs: Array = KF.D["crane"]["x"]
	for pass_i in 2:
		var best := -1
		var lo := INF
		for f in range(pass_i * 450 + 60, pass_i * 450 + 390):
			var v := absf(float(xs[(f + 1) % KF.NF]) - float(xs[f]))
			if v < lo - 1e-4:
				lo = v
				best = f
		var c := _hero(p, _cue(p, &"crane.brake", (best - 0.5) / 30.0, float(xs[best]), 120, crane, 0.0 if pass_i == 0 else -3.0))
		c.sync = Sync.HIT
	# the loading door: rolls up, then down (its panel's first and last moving frames)
	var opening := func(t: float) -> float: return KF.opening(KF.win(_kf(t), KF.DOOR_AT))
	for e in edges(func(t: float) -> bool: return float(opening.call(t)) > 0.0, p.loop):
		_hero(p, _cue(p, &"door.open", e, 560, 200, door, 0.0))
	var closing := func(t: float) -> bool:
		var o := float(opening.call(t))
		return o > 0.0 and o < 1.0 and float(opening.call(t - 1.0)) >= 1.0
	for e in edges(closing, p.loop):
		_hero(p, _cue(p, &"door.close", e, 560, 200, door, -5.0))
	# the engine test lights, and the hall's lamps sag under its draw (the first frame they dim and stay dim)
	var burn := func(t: float) -> bool: return KF.burn(KF.win(_kf(t), KF.ENGINE_AT)) > 0.0
	for e in edges(burn, p.loop):
		_cue(p, &"engine.spool", e, KF.PX, KF.PY, [&"engine_1"], -9.0).dark = 0.75
	var sag := func(t: float) -> bool:
		var f := _kf(t)
		return _sagging(f) and _sagging(f + 1.0 / 30.0) and _sagging(f + 2.0 / 30.0) and bool(burn.call(t))
	for e in edges(sag, p.loop):
		_cue(p, &"lamps.sag", e, 480, 60, [&"sag_1"], -12.0).dark = 0.6


static func _sagging(tf: float) -> bool:
	var row: Array = (KF.D["lamps"] as Array)[KF.pyround(tf * 30.0) % KF.NF]
	var s := 0.0
	for v: Variant in row:
		s += float(v)
	return s / 10000.0 / float(row.size()) < 0.99


static func _korvan_crew(p: Plan, r: ShipRoomKorvan) -> void:
	var weld: Array[StringName] = [&"weld_1", &"weld_2"]
	var grind: Array[StringName] = [&"grind_1", &"grind_2"]
	for ab in spans(func(t: float) -> bool: return KF.weld_pose(fposmod(_kf(t), 10.0)).y == 1, p.loop):
		_span(p, &"crew.weld.lift", ab, 465, 342, weld, -6.0, 4, 0.7)
	for sp: Dictionary in KF.K["weld8"]:
		var is_grind: bool = sp["kind"] == "grind"
		var on := func(t: float) -> bool: return KF.weld_state(sp, _kf(t)).y > 0.5
		for ab in spans(on, p.loop):
			if is_grind:
				_span(p, &"crew.grind.ladder", ab, float(sp["tip"][0]), 372, grind, -9.0, 3, 0.75)
			else:
				_span(p, &"crew.weld.ladder", ab, float(sp["tip"][0]), 372, weld, -9.0, 2, 0.7)
	for ab in spans(func(t: float) -> bool: return KF.in_any(_kf(t), KF.GRIND), p.loop):
		_span(p, &"crew.grind.bench", ab, 52, 302, grind, -16.0, 1, 0.8)
	# the courier sets his two crates down (the frame each stops being carried), and the drones the deck's crate
	var crate: Array[StringName] = [&"crate_1", &"crate_2"]
	var gains := [-4.0, -5.0]
	var set_n := 0
	for i in 2:
		var down := func(t: float) -> bool:
			var cs := r.front.crates_at(fposmod(_kf(t), 30.0))
			return cs.size() > i and cs[i].z < 0.5
		for e in edges(down, p.loop, 1.0 / 30.0):
			var cs := r.front.crates_at(fposmod(_kf(e), 30.0))
			if cs.size() <= i or not _was_carried(r, i, e):
				continue
			var c := _cue(p, &"crew.crate.set", e, cs[i].x + 7.0, cs[i].y + 7.0, crate, gains[mini(set_n, 1)])
			set_n += 1
			c.sync = Sync.HIT
			c.prio = 5
			c.dark = 0.4
	var landed := func(t: float) -> bool:
		var tc := KF.win(_kf(t), KF.DOOR_AT)
		return ShipRoomKorvanBack.stack_crate_shown(tc) and not ShipRoomKorvanBack.stack_crate_shown(tc - 0.1)
	for e in edges(landed, p.loop):
		var c := _cue(p, &"crew.crate.set", e, 527, 40, crate, -16.0)
		c.sync = Sync.HIT
		c.prio = 5
		c.dark = 0.4


## Was crate i in the courier's hands just before `t`?
static func _was_carried(r: ShipRoomKorvan, i: int, t: float) -> bool:
	var cs := r.front.crates_at(fposmod(_kf(t - 1.0 / 30.0), 30.0))
	return cs.size() > i and cs[i].z > 0.5


static func _korvan_moves(p: Plan) -> void:
	var vmax := 0.0
	var xs: Array = KF.D["crane"]["x"]
	for f in KF.NF:
		var v := absf(float(xs[(f + 1) % KF.NF]) - float(xs[f]))
		if v < 200.0:
			vmax = maxf(vmax, v)
	var crane := Layer.new()
	crane.id = &"crane.travel"
	crane.file = &"crane_travel_1"
	crane.gain = -8.0 - 7.0 * depth_of(120)
	crane.dark = 0.5 + 0.25
	crane.wet = 0.35 + 0.35
	crane.pan_k = 0.7
	crane.at_x = func(t: float) -> float: return float(xs[KF.pyround(t * 30.0) % KF.NF])
	crane.level = func(t: float) -> float:
		var f := KF.pyround(t * 30.0) % KF.NF
		var v := absf(float(xs[(f + 1) % KF.NF]) - float(xs[f]))
		return (v / vmax if v < 200.0 else 0.0) * _on_screen(float(xs[f]))
	p.layers.append(crane)
	var fork := Layer.new()
	fork.id = &"forklift.cross"
	fork.file = &"fork_1"
	fork.gain = -10.0 - 7.0 * depth_of(KF.FORK_LANE)
	fork.dark = minf(1.0, 0.75 + 0.25 * depth_of(KF.FORK_LANE))
	fork.wet = 0.35 + 0.35 * depth_of(KF.FORK_LANE)
	fork.pan_k = 0.7
	var fork_at := func(t: float) -> float:
		var x := KF.fork_x(_kf(t))
		return x + 40.0 if not is_nan(x) else -200.0
	fork.at_x = fork_at
	fork.level = func(t: float) -> float:
		var u := fposmod(_kf(t), 30.0)
		var on := clampf(minf(u - 1.0 + 0.8, 27.0 + 0.8 - u) / 1.6, 0.0, 1.0)
		return on * _on_screen(float(fork_at.call(t)))
	p.layers.append(fork)


static func _on_screen(x: float) -> float:
	return clampf(1.0 - maxf(0.0, maxf(-x, x - 960.0)) / 160.0, 0.0, 1.0)


# ------------------------------------------------------------------ Solari's casting bed (show18)
static func _solari(p: Plan, _r: ShipRoomSolari, cues: bool) -> void:
	p.loop = SC.LOOP
	p.beds.assign([&"s_bed_1", &"s_bed_2"])
	p.seg = 15.0
	p.air = &"s_air_1"
	var embers := Layer.new()
	embers.id = &"embers"
	embers.file = &"s_embers_1"
	embers.gain = -9.0
	embers.dark = 0.3
	embers.wet = 0.35
	p.layers.append(embers)
	if cues:
		_solari_shots(p)
		_solari_crew(p)


static func _solari_shots(p: Plan) -> void:
	var roar: Array[StringName] = [&"s_roar_1", &"s_roar_2"]
	var pour: Array[StringName] = [&"s_pour_1", &"s_pour_2"]
	for e in edges(func(t: float) -> bool: return SC.roar_k(t) > 0.0, p.loop):
		_hero(p, _cue(p, &"roar.furnace2", e, SC.TAPS[1], 150, roar, 0.0))
	for j in 6:
		var tap := j + 1
		# the stream reaches the mould FALL after the tap opens: the splash's first frame
		for e in edges(func(t: float) -> bool: return SC.u_of(j, t) >= SC.FALL and SC.u_of(j, t) < SC.P_DUR, p.loop):
			for lap in 2:
				var big := (tap == 4 and lap == 0) or (tap == 3 and lap == 1)
				var c := _cue(p, StringName("pour.tap%d" % tap), e, SC.TAPS[j], 165, pour, -2.0 if big else -8.0)
				if big:
					_hero(p, c)
				c.cut = 2.6
				c.dark = 0.2
				c.lap = lap


static func _solari_crew(p: Plan) -> void:
	var weld: Array[StringName] = [&"weld_1", &"weld_2"]
	var grind: Array[StringName] = [&"grind_1", &"grind_2"]
	for ab in spans(func(t: float) -> bool: return ShipRoomSolariCrew.weld_state(t)[1] == 1, p.loop):
		_span(p, &"crew.weld.lift", ab, ShipRoomSolariCrew.LIFT_X, 388, weld, -6.0, 4, 0.7)
	for ab in spans(func(t: float) -> bool: return ShipRoomSolariCrew.grind_on(t), p.loop):
		_span(p, &"crew.grind.fettler", ab, 294, 302, grind, -12.0, 1, 0.8)
	var plate: Array[StringName] = [&"plate_1", &"plate_2"]
	for j in 6:
		var X := SC.stack_x(j)
		if X < 0:
			continue
		# the plate lands on the stack: the jib's lowering ends (it stops carrying)
		for e in edges(func(t: float) -> bool: return not SC.jib_state(SC.u_of(j, t)).carry, p.loop):
			var c := _cue(p, &"crew.plate.set", e, X, 212, plate, -6.0)
			c.sync = Sync.HIT
			c.prio = 5
			c.dark = 0.4
			c.dur = 1.6
		# its chain runs while the hook goes down, lifts, lowers and comes up (over the mould, then the stack)
		for key: String in ["down", "lift", "lower", "up"]:
			var ab: Vector2 = SC.JIB[key]
			var t0 := SC.pour_t(j) + ab.x
			var xx := float(SC.TAPS[j]) if ab.x < 22.9 else float(X)
			_span(p, &"crew.jib.chain", Vector2(t0, t0 + ab.y - ab.x), xx, 150, [&"chain_1"], -12.0, 3, 0.75)
		# its trolley rolls in to be loaded and is pushed out with the plate
		for ab in _trolley_runs(j):
			var t0 := SC.pour_t(j) + ab.x
			var xm := (ShipRoomSolariCrew.trolley_at(j, ab.x + 0.01) + ShipRoomSolariCrew.trolley_at(j, ab.y - 0.01)) * 0.5
			_span(p, &"crew.trolley.roll", Vector2(t0, t0 + ab.y - ab.x), xm, 212, [&"trolley_1"], -12.0, 2, 0.6)


## Bay j's trolley's rolls on its handling clock (0 to 60 s): each run of frames it moves, gaps under 0.5 s closed.
static func _trolley_runs(j: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var step := 1.0 / 30.0
	var prev := ShipRoomSolariCrew.trolley_at(j, 0.0)
	var a := -1.0
	var last := -1.0
	for i in range(1, int(60.0 / step)):
		var ue := i * step
		var x := ShipRoomSolariCrew.trolley_at(j, ue)
		var moving := not is_nan(x) and not is_nan(prev) and x != prev
		if moving:
			if a < 0.0 or ue - last > 0.5:
				if a >= 0.0:
					out.append(Vector2(a, last))
				var x0 := prev
				a = _refine(func(u: float) -> bool: return ShipRoomSolariCrew.trolley_at(j, u) != x0, ue - step, ue)
			last = ue
		prev = x
	if a >= 0.0:
		out.append(Vector2(a, last))
	return out


# ------------------------------------------------------------------ the Old hangar's failing lamp (A17)
static func _old(p: Plan, r: ShipRoomOld, cues: bool) -> void:
	p.loop = ShipRoomOld.LOOP
	p.beds.assign([&"o_bed_1", &"o_bed_2"])
	p.seg = 10.0
	p.air = &"o_air_1"
	_old_layers(p, r)
	if cues:
		_old_shots(p)


static func _old_shots(p: Plan) -> void:
	var lamp: Array[StringName] = [&"o_lamp_1", &"o_lamp_2"]
	var out := func(t: float) -> bool: return ShipRoomOld.lamp_step(t) <= 0.0
	var outs := edges(out, p.loop)
	var backs := PackedFloat32Array()
	for o: Array in ShipRoomOld.OFFS:
		var t_back := float(o[0]) + float(o[1])
		backs.append(_refine(func(t: float) -> bool: return ShipRoomOld.lamp_step(t) > 0.5, t_back - 0.05, t_back + 0.02))
	for i in outs.size():
		_hero(p, _cue(p, &"lamp.die.short" if i == 0 else &"lamp.die", outs[i], 483, 60, lamp, -6.0 if i == 0 else 0.0))
	# the flicker (idea 1, filament tick): a fizz and pop on each out, a tick on each dip and as the light comes back
	var dips := edges(func(t: float) -> bool: return ShipRoomOld.lamp_step(t) < 1.0, p.loop)
	var sched: Array[Vector2] = []
	for e in outs:
		sched.append(Vector2(e, 1))
	for e in backs:
		sched.append(Vector2(e, 2))
	for e in dips:
		if not Array(outs).any(func(o: float) -> bool: return absf(o - e) < 0.002):
			sched.append(Vector2(e, 0))
	sched.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var kinds := [&"dip", &"out", &"back"]
	var nfiles := [4, 2, 2]
	for i in sched.size():
		var kind: StringName = kinds[int(sched[i].y)]
		var fs: Array[StringName] = []
		for v in nfiles[int(sched[i].y)]:
			fs.append(StringName("o_flick_%s_%d" % [kind, v + 1]))
		var c := _cue(p, StringName("flick." + kind), sched[i].x, 483, 60, fs, float(FLICK_GAIN[kind]) + FLICK_DB)
		c.k = i


static func _old_layers(p: Plan, r: ShipRoomOld) -> void:
	var hum := Layer.new()
	hum.id = &"lamp.hum"
	hum.file = &"o_hum_1"
	hum.gain = -10.0
	hum.dark = 0.3
	hum.wet = 0.3
	hum.x = 483
	hum.pan_k = 0.3
	hum.level = func(_t: float) -> float: return maxf(0.0, r.level())
	p.layers.append(hum)
	var buzz := Layer.new()
	buzz.id = &"lamp.buzz"
	buzz.file = &"o_buzz_1"
	buzz.gain = BUZZ_DB
	buzz.wet = 0.35 + 0.35
	buzz.x = 483
	buzz.pan_k = 0.3
	buzz.synced = true
	buzz.level = func(_t: float) -> float: return 0.0 if r.level() <= 0.0 else 1.0
	p.layers.append(buzz)
