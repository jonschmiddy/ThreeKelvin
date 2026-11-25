extends Node

## THE HEAVY LIFT (`ShipLift`, Jon's L1, Nov 12) on the front door's LAUNCH and the
## deck's UNDOCK and DOCK: each runs to its end and lands where it should, LAUNCH once, no
## click on the hall meanwhile, reduced motion a cut; the stands sink and rise every frame
## with their bases still. Headless, `--fixed-fps 60`.
## Why: docs/why/ShipLift.md#test

var _tree: SceneTree
var h := Harness.new()
var _t := 0.0


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


func _process(delta: float) -> void:
	_t += delta


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tree = get_tree()
	await Harness.frames(_tree, 2)
	Router.animate_in_harness = true
	var rm_was := DisplaySettings.reduced_motion
	DisplaySettings.reduced_motion = false
	await _launch()
	await _launch_reduced()
	await _undock()
	DisplaySettings.reduced_motion = rm_was
	h.verdict("shiplifttest")
	_tree.quit(h.code())


func _hull_pick() -> ChassisSelect:
	h.seed_run(4242)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_chassis_select()
	await Harness.frames(_tree, 6)
	var cs := Router.current as ChassisSelect
	if cs == null or not cs._yard.ready_hall:
		return null
	cs._pick_weight(HullData.Weight.MEDIUM)
	await Harness.frames(_tree, 3)
	return cs


## LAUNCH: the medium lifts, sinks its stands, smokes, burns off right; once.
func _launch() -> void:
	var cs := await _hull_pick()
	if not _ok("the hull pick opens on the city hall with a medium picked", cs != null and cs.launchable()):
		return
	var fired := [0]
	cs.launched.connect(func() -> void: fired[0] += 1)
	var berth := cs._yard.set_of(HullData.Weight.MEDIUM)
	# PARKED ON THE STANDS, ENGINES OUT (Jon, Nov 13): no rear flame, no nozzle glow
	var lit_parked := 0
	for w: HullData.Weight in cs._yard.sets:
		var pv: ShipView = (cs._yard.sets[w] as YardStandSet)._view
		if pv != null and (pv._thrust_now() >= 0 or not pv.engine_glow().is_empty()):
			lit_parked += 1
	_ok("the front door's parked hulls show no rear flame or glow (%d lit)" % lit_parked, lit_parked == 0)
	var x0 := berth.position.x
	var y0 := berth.position.y
	var key := Harness.button_with_text(cs, "LAUNCH")
	Audio.taping = true
	Audio.tape.clear()
	key.pressed.emit()
	var t0 := _t
	await Harness.frames(_tree, 1)
	var lift := cs._yard.lift
	_ok("LAUNCH starts the shared lift (`ShipLift`), not the run", lift != null and Router.current == cs and fired[0] == 0)
	if lift == null:
		return
	var lat: Array = []
	lift.lateral.connect(func(on: bool, v: float) -> void: lat.append([on, v, _t - t0, Engine.get_process_frames()]))
	# a second press, by the key and by the code, starts nothing more
	key.pressed.emit()
	cs._launch()
	await Harness.frames(_tree, 1)
	_ok("a second LAUNCH starts no second lift and no run", cs._yard.lift == lift and fired[0] == 0)
	# a click on another banner and on the floor while it flies changes nothing
	var b2 := cs._yard.banners[1].get_global_rect().get_center()
	for at: Vector2 in [b2, Vector2(300, 380)]:
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.position = at
			ev.global_position = at
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = pressed
			cs.get_viewport().push_input(ev)
			await Harness.frames(_tree, 1)
	_ok("no click reaches the hall while the ship is in the air (manufacturer %s, pick %d)" % [cs.manufacturer(), cs._picked],
		cs._sel == 0 and cs._picked == int(HullData.Weight.MEDIUM))
	var top := 0.0
	var right := 0.0
	var sunk := 0
	var below := -9999
	var bases0 := base_rects(berth)
	var feet := berth.feet
	var bases_moved := 0
	var lamps0 := cs._yard.room.lamp_k
	var lamps_moved := 0
	var light_jump := 0.0
	var light_prev := -1.0
	var smoke := 0
	var landed_at := -1.0
	var left_lit := 0
	var flame_at := -1.0
	var jets_f := -1
	var loop_f := -1
	for i in 900:
		if Router.current != cs:
			landed_at = _t - t0
			break
		if _t - t0 > ShipLift.exit_s() + 0.1 and _left_behind(lift, cs._yard.room.extra):
			left_lit += 1
		if flame_at < 0.0 and lift.view._thrust_now() >= 0:
			flame_at = _t - t0
		if jets_f < 0 and lift.plume.fired():
			jets_f = Engine.get_process_frames()
		if loop_f < 0 and Audio.ship_want > 0.0:
			loop_f = Engine.get_process_frames()
		top = minf(top, berth.position.y - y0)
		right = maxf(right, berth.position.x - x0)
		sunk = maxi(sunk, berth.retract)
		below = maxi(below, post_overrun(berth))
		if base_rects(berth) != bases0:
			bases_moved += 1
		if cs._yard.room.lamp_k != lamps0:
			lamps_moved += 1
		var lv := lift.plume.light_level()
		if light_prev >= 0.0:
			light_jump = maxf(light_jump, absf(lv - light_prev))
		light_prev = lv
		smoke = maxi(smoke, lift.plume.puffs())
		await _tree.process_frame
	# (Jon, Nov 24: "the stands go through the floor", then "sink only a little", "the bases must not move")
	# Why: docs/why/ShipRoom.md#posts-sink-into-their-bases
	_ok("it rises off its stands (%.0f px), the columns sink a little (%d rows), the smoke rolls (%d puffs)" % [-top, sunk, smoke],
		top <= -40.0 and sunk == ShipLift.SINK_ROWS and smoke >= 20)
	_ok("no column draws a row into its base or below the floor in any frame (at worst %d rows past the base's top)" % below,
		below <= 0)
	_ok("the bases never move, on their feet (%d frames moved, %s)" % [bases_moved, bases0],
		bases_moved == 0 and bases0.size() == 2 and bases0.all(func(r: Rect2) -> bool: return int(r.end.y) == feet))
	# (Jon's F1: no flicker -- the hall's lamps hold, the engines' light eases)
	_ok("the hall's lamps hold steady through the lift (%d frames moved), and its own light eases (at most %.3f a frame)" % [
		lamps_moved, light_jump], lamps_moved == 0 and light_jump <= 0.12)
	_ok("off the picture, nothing of it is left at the edge: its engines dark, no jet, nozzle or smoke light (%d frames lit)" % left_lit,
		left_lit == 0)
	_ok("it burns off the right edge (%.0f px across, off past %d)" % [right, YardFront.W],
		x0 + right > float(YardFront.W))
	_ok("the mains' sideways burn is reported once each way, going right, from %.2f s (%s)" % [ShipLift.MAINS_ON, lat],
		lat.size() == 2 and bool(lat[0][0]) and float(lat[0][1]) >= 0.0 and not bool(lat[1][0])
			and float(lat[0][2]) >= ShipLift.MAINS_ON - 0.02 and float(lat[0][2]) < ShipLift.exit_s())
	var lat_at := float(lat[0][2]) if not lat.is_empty() else -1.0
	_ok("no main flame through the rise: it lights with the sideways burn, on `MAINS_ON` (flame from %.3f s, the burn's signal at %.3f s, the beat %.2f s)" % [
		flame_at, lat_at, ShipLift.MAINS_ON], flame_at >= 0.0 and lat_at >= 0.0 and absf(flame_at - lat_at) < 0.02
			and flame_at >= ShipLift.MAINS_ON - 0.001)
	var heard := {}
	for tp: Array in Audio.tape:
		if tp.size() > 5 and not heard.has(String(tp[0])):
			heard[String(tp[0])] = int(tp[5])
	Audio.taping = false
	var mains_f := int(lat[0][3]) if not lat.is_empty() else -99
	var depart := String(ShipView.DEPART_SFX[int(HullData.Weight.MEDIUM)])
	var take_f := int(heard.get(String(ShipLift.LIFT_TAKE), -99))
	_ok("THE TAKEOFF HEARD: the take (%s) on the jets' first frame (frame %d, the jets at %d), within a frame" % [
		ShipLift.LIFT_TAKE, take_f, jets_f], jets_f >= 0 and absi(take_f - jets_f) <= 1)
	_ok("and the LTC layer on `MAINS_ON`: the departure burn (%s at frame %d) and the drive loop (from frame %d) with the burn's signal (frame %d), within a frame" % [
		depart, int(heard.get(depart, -99)), loop_f, mains_f],
		absi(int(heard.get(depart, -99)) - mains_f) <= 1 and absi(loop_f - mains_f) <= 1)
	_ok("the run starts when the lift ends (%.2f s; the lift %.2f s)" % [landed_at, ShipLift.front_s()],
		landed_at >= ShipLift.front_s() - 0.05 and landed_at <= ShipLift.front_s() + 0.2)
	await Harness.frames(_tree, 10)
	_ok("LOCAL, launched once (%d), in the picked hull" % fired[0], Router.current is SectorScreen and fired[0] == 1
		and Run.hull != null and Run.hull.weight == HullData.Weight.MEDIUM)


## Reduced motion: LAUNCH is a cut to the run, no lift.
func _launch_reduced() -> void:
	DisplaySettings.reduced_motion = true
	var cs := await _hull_pick()
	if not _ok("reduced motion: the hull pick with a medium picked", cs != null and cs.launchable()):
		DisplaySettings.reduced_motion = false
		return
	var yard := cs._yard
	Harness.button_with_text(cs, "LAUNCH").pressed.emit()
	var lifted := yard.lift != null
	await Harness.frames(_tree, 2)
	_ok("reduced motion: LAUNCH cuts straight to LOCAL, no lift", Router.current is SectorScreen and not lifted)
	DisplaySettings.reduced_motion = false


## UNDOCK from the Shipyard deck: the same lift, off to the right, then LOCAL undocked.
func _undock() -> void:
	ZoomLadder.force = 1
	ZoomLadder.fixed_dt = 1.0 / 60.0
	h.seed_run(1)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	StarchartScreen._primed_for = Run.galaxy_seed
	var stn := -1
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.STATION:
			stn = n.index
			break
	if not _ok("a station to dock at", stn >= 0):
		return
	Run.at = stn
	Run.map[stn].visited = true
	SectorScreen._approached_at = stn
	Router.park_at_station()
	ZoomLadder.force = 0
	Router.show_station()
	ZoomLadder.force = 1
	await Harness.frames(_tree, 120)
	var st := Router.current as StationScreen
	if not _ok("docked, on the Shipyard", st != null and Router.docked and st._mine_view != null):
		return
	_ok("on the deck's stands, your hull's engines are out: no rear flame, no glow (thrust %d)" % st._mine_view._thrust_now(),
		st._mine_view._thrust_now() < 0 and st._mine_view.engine_glow().is_empty())
	var rest := st._mine_view.position
	var t0 := _t
	Router.show_sector()
	var used := false
	var right := 0.0
	var top := 0.0
	var sunk := 0
	var smoke := 0
	var until := -1.0
	var left_lit := 0
	var t_lift := -1.0
	var deck := StandWatch.new()
	for i in 1500:
		await _tree.process_frame
		if Router.current == st and is_instance_valid(st) and st._heavy != null:
			if t_lift < 0.0:
				t_lift = _t
			if _t - t_lift > StationScreen.undock_elev_s() + ShipLift.exit_s() + 0.1 and _left_behind(st._heavy, st._scene.life.extra if st._scene.life != null else []):
				left_lit += 1
			used = true
			right = maxf(right, st._mine_view.position.x - rest.x)
			top = minf(top, st._mine_view.position.y - rest.y)
			sunk = maxi(sunk, deck.see(st._scene))
			smoke = maxi(smoke, st._heavy.plume.puffs())
		if until < 0.0 and Router.current is SectorScreen and not ZoomLadder.busy():
			until = _t - t0
			break
	_ok("UNDOCK runs the shared lift on the deck", used)
	_ok("off the yard, nothing of it is left at the edge (%d frames lit)" % left_lit, left_lit == 0)
	# (Jon, Nov 25: "For taking off, it should look just like the new ship picker launch")
	# Why: docs/why/ShipLift.md#stands-sink-and-rise
	_ok("off its stands (%.0f px up), the columns sink a little into their bases (%d rows, the deck's %d), the smoke rolls (%d puffs), and away to the RIGHT (%.0f px)" % [
		-top, sunk, ShipLift.sunk_rows(ShipLift.DECK_K), smoke, right],
		top <= -25.0 and sunk == ShipLift.sunk_rows(ShipLift.DECK_K) and smoke >= 20 and right > 200.0)
	deck.verdict(h, "UNDOCK")
	_ok("it lands on LOCAL undocked (%.2f s; the yard's part %.2f s)" % [until, ZoomLadder.UNDOCK_YARD_S],
		until > ZoomLadder.UNDOCK_YARD_S and Router.current is SectorScreen and not Router.docked)
	await _land()
	ZoomLadder.force = -1
	ZoomLadder.fixed_dt = -1.0


## DOCK onto the Shipyard deck, the undock run back (Jon, Nov 25: "they should be down at first and come
## up as the ship approaches"): down from the first frame, up as it slows over them, before it touches down.
## Why: docs/why/ShipLift.md#stands-sink-and-rise
func _land() -> void:
	var full := ShipLift.sunk_rows(ShipLift.DECK_K)
	var up_at := ShipLift.RAISE_FROM + ShipLift.SINK_S
	var touch_at := ShipLift.LAND_FLY_S + ShipLift.LAND_HOVER_S + ShipLift.LAND_DOWN_S
	Router.show_station()
	var deck := StandWatch.new()
	var first := -1
	var early_up := 0
	var late_down := 0
	var went_down := 0
	var part := 0
	var at_touch := -1
	var dip := false
	var prev := full
	var flown := 0
	for i in 1500:
		await _tree.process_frame
		var st := Router.current as StationScreen
		if st != null and is_instance_valid(st) and st._scene != null and not st._lad.is_empty() and not bool(st._lad.out):
			var s := deck.see(st._scene)
			var yt := float(st._lad.get("yard_t", -INF))
			if first < 0:
				first = s
			if yt < ShipLift.RAISE_FROM and s != full:
				early_up += 1
			if yt >= up_at and s != 0:
				late_down += 1
			if s > prev:
				went_down += 1
			if s > 0 and s < full:
				part += 1
			if yt >= touch_at and at_touch < 0:
				at_touch = s
			if yt > -INF:
				flown += 1
			if st._heavy != null and yt >= touch_at and yt < touch_at + ShipLift.LAND_SETTLE_S * 0.5 and st._heavy.offset().y >= 1.0:
				dip = true
			prev = s
		if Router.current is StationScreen and Router.docked and not ZoomLadder.busy():
			break
	var st2 := Router.current as StationScreen
	if not _ok("DOCK flies the landing onto the deck (%d frames on the yard's clock)" % flown, flown > 60 and st2 != null):
		return
	_ok("the stands are down in their bases from the landing's first frame (%d rows, the deck's %d), and stay down until %.2f s (%d frames up early)" % [
		first, full, ShipLift.RAISE_FROM, early_up], first == full and early_up == 0)
	_ok("they come up as it comes in, never going back down (%d frames part way up, %d frames down again)" % [part, went_down],
		part >= 3 and went_down == 0)
	_ok("fully up by %.2f s, before the hover ends and well before touchdown at %.2f s (%d frames still down after; %d rows down at touchdown)" % [
		up_at, touch_at, late_down, at_touch], up_at <= ShipLift.LAND_FLY_S + ShipLift.LAND_HOVER_S and late_down == 0 and at_touch == 0)
	_ok("and they take its weight with a pixel's give", dip)
	deck.verdict(h, "DOCK")
	_ok("docked, the stands up (%d rows down)" % st2._scene.sink_mine, Router.docked and st2._scene.sink_mine == 0)


## Your ship's stands on the deck as `YardScene.stand_pieces` draws them, frame by frame: how far the
## columns are down, whether one drew a row into its base, whether a base moved off its feet.
class StandWatch:
	var bases0: Array[Rect2] = []
	var floor_y := 0
	var base_rows := 99
	var frames := 0
	var moved := 0
	var over := -9999

	## How far down your stands' columns are this frame (rows).
	func see(sc: YardScene) -> int:
		var ps := sc.stand_pieces(0)
		var bases: Array[Rect2] = []
		var sunk := 0
		for p: Array in ps:
			var col: Rect2 = p[2]
			var base: Rect2 = p[4]
			bases.append(base)
			base_rows = mini(base_rows, int((p[3] as Rect2).size.y))
			sunk = maxi(sunk, int((p[3] as Rect2).position.y - (p[1] as Rect2).size.y))
			if col.size.y > 0.0:
				over = maxi(over, int(ceilf(col.end.y - base.position.y)))
		if frames == 0:
			bases0 = bases
			floor_y = int(sc.placed[0].get("floor", -1)) if not sc.placed.is_empty() else -1
		elif bases != bases0:
			moved += 1
		frames += 1
		return sunk

	func verdict(hh: Harness, what: String) -> void:
		hh._ok("%s: every stand has a bolted base (%d rows at least) on the floor (%s, floor %d)" % [what, base_rows, bases0, floor_y],
			bases0.size() == 2 and base_rows >= 15 and bases0.all(func(r: Rect2) -> bool: return int(r.end.y) == floor_y))
		hh._ok("%s: the bases never move (%d of %d frames moved), and no column draws a row into its base (at worst %d rows past its top)" % [
			what, moved, frames, over], frames > 0 and moved == 0 and over <= 0)


## Anything of the lift still lit on the picture once the hull is off it: its flame,
## the jets' or nozzle's light, or a small light it put in the yard's light (one
## still easing out past the picture's right edge, with the hull, is not on it).
func _left_behind(lift: ShipLift, extra: Array) -> bool:
	if lift.view._thrust_now() >= 0 or lift.lit() > 0:
		return true
	var edge := float(lift.host.size.x)
	var lit: Array = lift.plume.lights()
	lit.append_array(extra)
	for l: Array in lit:
		if float(l[0]) - float(l[2]) < edge:
			return true
	return false


## How many rows past its base's top the lowest drawn row of a berth's standing columns reaches (0 or less:
## none), counting the texture's own rows, so a clip that does not hold still fails.
static func post_overrun(s: YardStandSet) -> int:
	var worst := -9999
	for tr in s._posts:
		if not tr.visible or tr.texture == null:
			continue
		var top := s.position.y + tr.position.y
		var rows := maxf(float(tr.texture.get_height()), tr.size.y)
		worst = maxi(worst, int(ceilf(top + rows)) - (s.feet - YardStandSet.POST_BASE))
	return worst


## Each post's base as drawn in the frame (its rect and its texture's rows).
static func base_rects(s: YardStandSet) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for b in s._bases:
		var at := s.position + b.position
		out.append(Rect2(at, Vector2(b.size.x, maxf(b.size.y, float(b.texture.get_height())))))
	return out
