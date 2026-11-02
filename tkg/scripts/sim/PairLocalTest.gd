extends Node

## THE PAIR AS THE MAP LEFT IT, IN LOCAL AND THROUGH A SAVE (ruling 23, Jon,
## Nov 1: "Orbiting pair"), headless:
##   godot --headless --fixed-fps 60 --path . -- sheet=PairLocalTest
## A binary's suns turn round their balance point on the system's map clock,
## and map time does not run off the map, so LOCAL holds the pair where the map
## left it (`LocalSky._hold_pair`) and the map opens on that angle again.
##  1. AT 8 OF THE PAIR'S ANGLES round a lap, a wide pair (the ship at the world
##     round star B) and a close one (the ship in star B's close orbit): LOCAL
##     built at that kept clock holds that clock and that angle; star B on the
##     band on the side of star A the map has it, and the nearer sun the one
##     nearer on the map (drawn over the farther, stacked:A); a wide pair's B
##     where the band puts the pair's line from A, a close pair's pushed clear
##     of A's disc only while the pair lies within TWIN_TURN of level, and not
##     at all end on (the suns one in front of the other); the lit sun the one
##     lighting the ship's place (its own); a world round star B within its
##     orbit of B on the band, and still there a minute of LOCAL's clock on.
##  2. MAP -> LOCAL -> MAP: the map's clock goes into LOCAL whole, LOCAL holds it
##     while it is up, and the map opens on it again. IN CO-OP, a partner's map
##     clock 10 s ahead, with the zoom ladder off and on: at both handovers
##     the picture coming up has the clock of the one going (LOCAL does not take
##     the party's from its map, the map does not take it from LOCAL), the kept
##     clock never goes back, and the map then catches up with the party, a
##     little faster than time and never by a jump (review 1), level within
##     LEVEL_S. Ten minutes on instead, too far to catch up (CATCH_CUT), the
##     map out of LOCAL takes the party's clock at once. And three rounds of
##     4 s on the map and 4 s in LOCAL, the partner's map running: the gap
##     shrinks round by round (review 2).
##     OPENED ANY OTHER WAY (out of the chart), a map and LOCAL take the
##     party's clock at once, and a ship parked settled round star B goes with
##     B (review 2).
##  3. A SAVE: the clock written, the run's clocks scrambled, the save read back:
##     LOCAL opens on the very angle.
##  4. ONE SUN: star A at the band's anchor and nothing turned, at any clock.

const TILT := 0.07

var _fails := 0
var _tree: SceneTree


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


## A system of the run with a turning pair of this kind, or -1.
func _pair_of(close: bool) -> int:
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.START:
			continue
		var L := SystemLayout.of(n)
		if L.twin and L.close == close and L.pair_n > 0.0:
			return n.index
	return -1


## LOCAL's sky for system `idx` built as LOCAL builds it, off the screen.
func _sky_at(idx: int) -> LocalSky:
	var s := LocalSky.new()
	s.setup(Run.map[idx])
	return s


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Router.animate_in_harness = true
	ZoomLadder.force = 0
	SaveGame.clear()
	var found := {}
	for seed in [7, 4242, 77, 1, 9, 11]:
		Rng.forced = seed
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		if _pair_of(false) >= 0 and _pair_of(true) >= 0:
			found = {"seed": seed}
			break
	if not _ok("a galaxy with a turning wide pair and a turning close one (seed %s)" % found.get("seed", "none"), not found.is_empty()):
		_end()
		return
	_sweep(false)
	_sweep(true)
	await _through_the_map()
	for ladder in [0, 1]:
		for lead: float in [10.0, 600.0]:
			await _coop_handovers(ladder, lead)
	await _coop_rounds()
	await _coop_opened_cold()
	ZoomLadder.force = 0
	await _through_a_save()
	_one_sun()
	_end()


func _end() -> void:
	SaveGame.clear()
	print("pairlocaltest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)


## 1. The sweep: 8 angles round a lap.
func _sweep(close: bool) -> void:
	var kind := "close" if close else "wide"
	var idx := _pair_of(close)
	var L := SystemLayout.of(Run.map[idx])
	var B := SystemLayout.STAR_B
	var wb := -1
	for b in L.bodies:
		if b.host_id == B and b.hr != 0.0 and b.world != &"":
			wb = b.index
			break
	var at := B if close or wb < 0 else wb
	SystemMapScreen._parked[idx] = {"at": at, "p": Vector2.ZERO, "v": Vector2.ZERO, "head": 0.0, "mode": &"rail"}
	var held_bad := 0
	var side_bad := 0
	var depth_bad := 0
	var place_bad := 0
	var lit_bad := 0
	var world_bad := 0
	var pushed := 0
	var notes: Array[String] = []
	for k in 8:
		var tm := (float(k) + 0.25) / 8.0 * TAU / L.pair_n
		Run.map_clock[idx] = tm
		var s := _sky_at(idx)
		if absf(s.held_t() - tm) > 1e-9 or absf(angle_difference(s.held_angle(), L.pair_angle(tm))) > 1e-6:
			held_bad += 1
		var rel := L.star_pos(B, tm) - L.star_pos(-1, tm)
		var on_band := s._sun_at(B) - s._sun
		var want := Vector2(rel.x, rel.y * TILT) * s._s
		# (the side across: the map's plane x is its screen x)
		if absf(want.x) > 4.0 and signf(on_band.x) != signf(want.x):
			side_bad += 1
		# (the nearer sun the map's nearer: plane depth, toward the viewer positive)
		if signf(s.suns_depth()) != signf(rel.y) and absf(rel.y) > 0.5:
			depth_bad += 1
		var lv := absf(rel.x) / rel.length()
		if not close:
			if on_band.distance_to(want) > 2.0:
				place_bad += 1
		else:
			# (pushed out along the pair's line to SUNS_APART past both discs, by
			# `apart_k`: all of it within TWIN_TURN of level, so a pair as laid
			# out is drawn as it always was)
			var ra := L.star_r * s.star_k_of(-1)
			var rb := L.star2_r * s.star_k_of(B)
			var need := (ra + rb + LocalSky.SUNS_APART) * LocalSky.apart_k(rel)
			var exp := want if want.length() >= need else want.normalized() * need
			if on_band.distance_to(exp) > 2.0:
				place_bad += 1
				notes.append("at %.0f deg B %s on the band, wanted %s" % [rad_to_deg(L.pair_angle(tm)), on_band, exp])
			if lv >= cos(SystemLayout.TWIN_TURN) and on_band.length() < ra + rb + LocalSky.SUNS_APART - 2.0:
				place_bad += 1
				notes.append("at %.0f deg, as a layout lays a pair, the discs not apart" % rad_to_deg(L.pair_angle(tm)))
			if on_band.length() > want.length() + 2.0:
				pushed += 1
		if s._lit != B:
			lit_bad += 1
		if wb >= 0 and not close:
			var bw: SystemLayout.Body = L.bodies[wb]
			for tl: float in [0.0, 60.0]:
				s.t = tl
				var q := s._band_pos(bw)
				if absf(q.distance_to(rel) - bw.orbit) > 0.01:
					world_bad += 1
			s.t = 0.0
		s.free()
	if close:
		# END ON (stacked:A): the clock the pair's line points straight at the
		# viewer, star B the nearer -- the discs cross on the band, B over A
		var tz := fposmod((0.5 * PI - L.pair_ph) / L.pair_n, TAU / L.pair_n)
		Run.map_clock[idx] = tz
		var se := _sky_at(idx)
		var rel_e := L.star_pos(B, tz) - L.star_pos(-1, tz)
		var gap_e := (se._sun_at(B) - se._sun).length()
		var r_both := L.star_r * se.star_k_of(-1) + L.star2_r * se.star_k_of(B)
		_ok("close pair end on (%.0f deg): its suns cross on the band (%.1f px apart, discs %.1f across together), star B the nearer (%.1f)" % [
			rad_to_deg(L.pair_angle(tz)), gap_e, r_both, se.suns_depth()], gap_e < r_both and se.suns_depth() > 0.0 and rel_e.y > 0.0)
		# THE DRAWING ORDER (`LocalSky.band_order`, what `_step_worlds` moves the
		# suns and worlds by; not built headless): end on with B nearer, B after
		# A, and the other way half a lap on, each among the band's worlds by
		# depth -- the real band's, and one with a world far nearer than both
		var tz2 := tz + 0.5 * TAU / L.pair_n
		Run.map_clock[idx] = tz2
		var so := _sky_at(idx)
		var e_ok := _drawn_in_depth(se, true) and _drawn_in_depth(so, false)
		_ok("close pair end on: LOCAL draws the nearer sun after the farther, among the worlds by depth (B nearer %s, A nearer %s)" % [
			str(LocalSky.band_order(se.suns_depth(), [-200.0, 300.0])), str(LocalSky.band_order(so.suns_depth(), [-200.0, 300.0]))], e_ok)
		so.free()
		se.free()
	_ok("%s pair (system %d): LOCAL holds the kept clock and the pair's angle there, 8 of 8 (%d off)" % [kind, idx, held_bad], held_bad == 0)
	_ok("%s pair: star B on the band on the side of star A the map has it (%d of 8 wrong)" % [kind, side_bad], side_bad == 0)
	_ok("%s pair: the nearer sun on the band the map's nearer, so drawn over the farther (%d of 8 wrong)" % [kind, depth_bad], depth_bad == 0)
	if close:
		_ok("close pair: star B on the band along the pair's line, pushed clear of star A's disc by `apart_k` (%d of 8 pushed)%s" % [pushed,
			"" if notes.is_empty() else ": " + ", ".join(notes)], place_bad == 0)
	else:
		_ok("wide pair: star B where the band puts the pair's line from star A, within a block (%d of 8 off)" % place_bad, place_bad == 0)
	_ok("%s pair: the ship's place lit by star B, its own sun, at every angle (%d of 8 not)" % [kind, lit_bad], lit_bad == 0)
	if not close:
		_ok("wide pair: the world round star B on the band on its orbit of B, now and a minute on (%d of 16 off)" % world_bad, wb >= 0 and world_bad == 0)
	SystemMapScreen._parked.erase(idx)
	Run.map_clock.erase(idx)


## Whether LOCAL sky `s` draws its band farthest first (`LocalSky.band_order`):
## its suns and its worlds in depth order, star B after star A exactly when
## `b_near`; for the band's own worlds at its clock and for a band with one
## world far behind both suns and one far nearer.
func _drawn_in_depth(s: LocalSky, b_near: bool) -> bool:
	var d2 := s.suns_depth()
	var ok := (d2 > 0.0) == b_near
	var real: Array = []
	for b in s.layout.bodies:
		real.append(s._band_pos(b).y)
	real.sort()
	for ys: Array in [real, [-200.0, 300.0], []]:
		var out := LocalSky.band_order(d2, ys)
		var last := -INF
		for e: int in out:
			var y: float = 0.0 if e == -1 else (d2 if e == SystemLayout.STAR_B else float(ys[e]))
			ok = ok and y >= last
			last = y
		ok = ok and out.size() == ys.size() + 2 and (out.find(SystemLayout.STAR_B) > out.find(-1)) == b_near
	return ok


## 2. Map -> LOCAL -> map, through the screens.
func _through_the_map() -> void:
	var idx := _pair_of(true)
	var L := SystemLayout.of(Run.map[idx])
	var node: MapGen.MapNode = Run.map[idx]
	node.visited = true
	Run.at = idx
	SectorScreen._approached_at = idx
	var t0 := 0.3 * TAU / L.pair_n
	Run.map_clock[idx] = t0
	SystemMapScreen._parked[idx] = {"at": SystemLayout.STAR_B, "p": Vector2.ZERO, "v": Vector2.ZERO, "head": 0.0, "mode": &"rail"}
	Router.show_system()
	await _frames(20)
	var m := Router.current as SystemMapScreen
	if not _ok("the map is up over the close pair", m != null and m.view.node == node):
		return
	_ok("the map opened on the kept clock and ran on from it (%.3f, kept %.3f)" % [m.view.t, t0], m.view.t >= t0 and m.view.t - t0 < 2.0)
	var left := float(m.view.t)
	Router.show_local()
	await _frames(6)
	var sky := _local_sky()
	if not _ok("LOCAL is up", sky != null):
		return
	_ok("LOCAL holds the clock the map was left at (%.6f, left at %.6f)" % [sky.held_t(), left], absf(sky.held_t() - left) < 1e-9)
	_ok("and the pair's angle then", absf(angle_difference(sky.held_angle(), L.pair_angle(left))) < 1e-6)
	var b_before := sky._sun_at(SystemLayout.STAR_B)
	# (the map, hidden as LOCAL is built, is freed a frame later and writes its
	# clock again as it goes, `_keep_ship`: hidden, its clock holds,
	# `clock_held`, so the clock kept is LOCAL's to the bit -- it ran a frame on
	# before, review 1 -- and from there it must not move)
	var kept := Run.map_t(idx)
	_ok("the clock kept as the map went is LOCAL's (%.6f, LOCAL %.6f)" % [kept, sky.held_t()],
		kept == left and kept == sky.held_t())
	await _frames(30)
	_ok("held while LOCAL is up: the clock not run on (%.6f) and star B not moved on the band" % Run.map_t(idx),
		Run.map_t(idx) == kept and sky._sun_at(SystemLayout.STAR_B) == b_before and absf(sky.held_t() - left) < 1e-9)
	Router.show_system()
	await _frames(4)
	m = Router.current as SystemMapScreen
	if _ok("the map is up again", m != null):
		_ok("and opened on the angle LOCAL held (%.3f, LOCAL %.3f)" % [m.view.t, left], m.view.t >= left and m.view.t - left < 1.0)
	Router.show_local()
	await _frames(4)


## 2b. In co-op, a partner's clock ahead by `lead`: under CATCH_CUT the
## handovers keep one clock and the map then catches up, level within
## LEVEL_S; further on, the map out of LOCAL takes the party's at once
## (`NetSession.handed_clock`, review 2: caught up at CATCH_K alone, 10
## minutes in LOCAL took 40 to come level).
const LEVEL_S := 25.0
func _coop_handovers(ladder: int, lead: float) -> void:
	ZoomLadder.force = ladder
	var far := lead > NetSession.CATCH_CUT
	var how := "the ladder %s, the partner %.0f s on" % ["on" if ladder == 1 else "off", lead]
	var idx := _pair_of(true)
	var L := SystemLayout.of(Run.map[idx])
	var node: MapGen.MapNode = Run.map[idx]
	node.visited = true
	Run.at = idx
	SectorScreen._approached_at = idx
	var t0 := 0.55 * TAU / L.pair_n
	Run.map_clock[idx] = t0
	SystemMapScreen._parked[idx] = {"at": SystemLayout.STAR_B, "p": Vector2.ZERO, "v": Vector2.ZERO, "head": 0.0, "mode": &"rail"}
	Router.show_system()
	for i in 240:
		await _tree.process_frame
		if Router.current is SystemMapScreen and not ZoomLadder.busy():
			break
	var m := Router.current as SystemMapScreen
	if not _ok("co-op, %s: the map is up over the close pair" % how, m != null and m.view.node == node):
		return
	# A PARTNER ON THIS SYSTEM'S MAP, `lead` further on, its map up (held, far
	# on, so its clock is exactly the one said)
	var kept_state := Net.state
	Net.state = NetSession.State.DIVING
	_partner(idx, float(m.view.t) + lead, far)
	var back := 0
	var last := Run.map_t(idx)
	# MAP -> LOCAL
	var left := float(m.view.t)
	Router.show_local()
	var sky: LocalSky = null
	for i in 240:
		await _tree.process_frame
		if Run.map_t(idx) < last:
			back += 1
		last = maxf(last, Run.map_t(idx))
		sky = _local_sky()
		if sky != null and not ZoomLadder.busy():
			break
	if not _ok("co-op, %s: LOCAL is up" % how, sky != null):
		Net.state = kept_state
		_no_partner()
		return
	_ok("co-op, %s: LOCAL holds the map's clock, not the party's (%.6f, the map left at %.6f; the party %.3f)" % [how, sky.held_t(), left, Net.party_t(idx)],
		sky.held_t() == left)
	await _frames(20)
	_ok("co-op, %s: and the clock kept is LOCAL's (%.6f)" % [how, Run.map_t(idx)], Run.map_t(idx) == sky.held_t())
	var held := sky.held_t()
	# LOCAL -> MAP
	var pt_before := Net.party_t(idx)
	Router.show_system()
	var at_swap := -1.0
	for i in 240:
		await _tree.process_frame
		if Run.map_t(idx) < last:
			back += 1
		last = maxf(last, Run.map_t(idx))
		var m2 := Router.current as SystemMapScreen
		if m2 != null and at_swap < 0.0:
			at_swap = float(m2.view.t)
		if m2 != null and not ZoomLadder.busy():
			break
	m = Router.current as SystemMapScreen
	if not _ok("co-op, %s: the map is up again" % how, m != null):
		Net.state = kept_state
		_no_partner()
		return
	if far:
		_ok("co-op, %s: too far behind to catch up, the map comes up on the party's clock, within a frame (%.6f, the party %.6f; LOCAL %.6f)" % [how, at_swap, pt_before, held],
			at_swap >= pt_before and at_swap - pt_before <= 1.5 / 60.0)
	else:
		# (within a frame: its first frame may already be one of catching up)
		_ok("co-op, %s: the map comes up on LOCAL's clock, within a frame (%.6f, LOCAL %.6f)" % [how, at_swap, held],
			at_swap >= held and at_swap - held <= (1.0 + SystemMapScreen.CATCH_MAX) / 60.0 + 1e-4)
	# THE MAP CATCHES UP: faster than time, never by a jump, never past the
	# party, and level within LEVEL_S
	var worst := 0.0
	var t_prev := float(m.view.t)
	var t_first := t_prev
	var level_at := -1.0
	for i in int(LEVEL_S * 60.0) + 1:
		await _tree.process_frame
		var tn := float(m.view.t)
		worst = maxf(worst, tn - t_prev)
		if Run.map_t(idx) < last:
			back += 1
		t_prev = tn
		if i == 119 and not far:
			var ran := t_prev - t_first
			_ok("co-op, %s: the map then catches up with the party, %.3f s of map time in 2 s, at most %.4f s a frame (never a jump), not past it (%.3f, the party %.3f)" % [how, ran, worst, t_prev, Net.party_t(idx)],
				ran > 2.0 * 1.1 and worst <= (1.0 + SystemMapScreen.CATCH_MAX) / 60.0 + 1e-4 and t_prev <= Net.party_t(idx) + 1e-6)
		if level_at < 0.0 and (far or Net.party_t(idx) - tn < 0.05):
			level_at = float(i + 1) / 60.0
			break
	_ok("co-op, %s: and level with the party within %.0f s (%s)" % [how, LEVEL_S, "%.2f s" % level_at if level_at >= 0.0 else "not"], level_at >= 0.0)
	_ok("co-op, %s: and the kept clock never went back (%d times)" % [how, back], back == 0)
	Router.show_local()
	for i in 240:
		await _tree.process_frame
		if _local_sky() != null and not ZoomLadder.busy():
			break
	Net.state = kept_state
	_no_partner()


## 2c. MAP AND LOCAL IN TURN, in co-op, with a partner whose map runs on (its
## clock said every frame, a frame on): three rounds of 4 s on the map and 4 s
## in LOCAL from 16 s behind. LOCAL holds the clock each time while the
## partner's runs, and the map must win back more than that: the gap shrinks
## round by round and never reaches CATCH_CUT (review 2: at CATCH_K alone it
## grew by about 3 s a round, for good).
func _coop_rounds() -> void:
	ZoomLadder.force = 0
	var idx := _pair_of(true)
	var L := SystemLayout.of(Run.map[idx])
	var node: MapGen.MapNode = Run.map[idx]
	node.visited = true
	Run.at = idx
	SectorScreen._approached_at = idx
	Run.map_clock[idx] = 0.2 * TAU / L.pair_n
	SystemMapScreen._parked[idx] = {"at": SystemLayout.STAR_B, "p": Vector2.ZERO, "v": Vector2.ZERO, "head": 0.0, "mode": &"rail"}
	Router.show_system()
	await _frames(6)
	var m := Router.current as SystemMapScreen
	if not _ok("co-op rounds: the map is up over the close pair", m != null and m.view.node == node):
		return
	var kept_state := Net.state
	Net.state = NetSession.State.DIVING
	var pt := float(m.view.t) + 16.0
	_partner(idx, pt, false)
	var gaps: Array[float] = []
	var most := 0.0
	for r in 3:
		for i in 240:
			await _tree.process_frame
			pt += 1.0 / 60.0
			_partner(idx, pt, false)
			if i == 0:
				m = Router.current as SystemMapScreen
		if m == null or not is_instance_valid(m):
			break
		gaps.append(pt - float(m.view.t))
		Router.show_local()
		for i in 240:
			await _tree.process_frame
			pt += 1.0 / 60.0
			_partner(idx, pt, false)
			most = maxf(most, pt - Run.map_t(idx))
		Router.show_system()
		m = null
	var shrank := gaps.size() == 3 and gaps[2] < gaps[1] and gaps[1] < gaps[0]
	var said := PackedStringArray()
	for g in gaps:
		said.append("%.2f" % g)
	_ok("co-op rounds: the gap after each 4 s on the map shrinks round by round (%s s), and never reaches CATCH_CUT (at most %.2f s)" % [
		", ".join(said), most], shrank and most < NetSession.CATCH_CUT)
	await _frames(4)
	Router.show_local()
	await _frames(4)
	Net.state = kept_state
	_no_partner()


## 2d. OPENED ANY OTHER WAY, IN CO-OP: a map or LOCAL opened after something
## that showed no angle of the pair (here the chart) takes the party's clock at
## once (`Router.show_system`'s and `LocalSky._hold_pair`'s `adopt_clock`),
## and a ship parked settled round star B goes with B to where it stands then
## (`NetSession.carry_parked`). Cut either call and the gate stayed green while
## two machines opened the pair at two angles (review 2).
func _coop_opened_cold() -> void:
	ZoomLadder.force = 0
	var idx := _pair_of(true)
	var L := SystemLayout.of(Run.map[idx])
	var B := SystemLayout.STAR_B
	var node: MapGen.MapNode = Run.map[idx]
	node.visited = true
	Run.at = idx
	SectorScreen._approached_at = idx
	Run.map_clock[idx] = 0.35 * TAU / L.pair_n
	SystemMapScreen._parked[idx] = {"at": B, "p": Vector2.ZERO, "v": Vector2.ZERO, "head": 0.0, "mode": &"rail"}
	var kept_state := Net.state
	Net.state = NetSession.State.DIVING
	# THE MAP, out of the chart
	Router.show_starchart()
	for i in 120:
		await _tree.process_frame
		if Router.current is StarchartScreen:
			break
	if not _ok("co-op, cold: the chart is up", Router.current is StarchartScreen):
		Net.state = kept_state
		return
	var own := Run.map_t(idx)
	_partner(idx, own + 60.0, true)
	var pt := Net.party_t(idx)
	Router.show_system()
	var m := Router.current as SystemMapScreen
	_ok("co-op, cold: the map opened out of the chart takes the party's clock at once (%.6f; its own %.3f, the party %.6f)" % [
		m.view.t if m != null else -1.0, own, pt], m != null and m.view.node == node and absf(m.view.t - pt) < 1e-6 and Run.map_t(idx) == pt)
	await _frames(4)
	# LOCAL, out of the chart, a ship parked settled round star B
	Router.show_starchart()
	for i in 120:
		await _tree.process_frame
		if Router.current is StarchartScreen:
			break
	own = Run.map_t(idx)
	_partner(idx, own + 60.0, true)
	pt = Net.party_t(idx)
	var off := Vector2(31.0, -12.5)
	var p_own := L.star_pos(B, own) + off
	SystemMapScreen._parked[idx] = {"at": -9, "mode": &"free", "p": p_own, "v": Vector2.ZERO, "head": 0.0, "cen": B, "r": off.length(), "sense": 1.0}
	Router.show_local()
	var sky: LocalSky = null
	for i in 240:
		await _tree.process_frame
		sky = _local_sky()
		if sky != null and not ZoomLadder.busy():
			break
	var p_now: Vector2 = (SystemMapScreen._parked.get(idx, {}) as Dictionary).get("p", Vector2.INF)
	_ok("co-op, cold: LOCAL opened out of the chart takes the party's clock at once (%.6f; its own %.3f, the party %.6f)" % [
		sky.held_t() if sky != null else -1.0, own, pt], sky != null and absf(sky.held_t() - pt) < 1e-6)
	_ok("co-op, cold: and the ship parked settled round star B went with B (%.4f px off its offset; B moved %.1f px)" % [
		(p_now - L.star_pos(B, pt)).distance_to(off), L.star_pos(B, pt).distance_to(L.star_pos(B, own))],
		(p_now - L.star_pos(B, pt)).distance_to(off) < 1e-3 and L.star_pos(B, pt).distance_to(L.star_pos(B, own)) > 1.0)
	Net.state = kept_state
	_no_partner()
	SystemMapScreen._parked[idx] = {"at": B, "p": Vector2.ZERO, "v": Vector2.ZERO, "head": 0.0, "mode": &"rail"}


## A PARTNER (peer 77) in system `idx` on the roster, its map's clock `t`
## said just now, held or running (`NetSession.party_t` counts a partner only
## where the roster has it).
func _partner(idx: int, t: float, held: bool) -> void:
	Net.roster[77] = Net._slot(77, "PARTNER", &"korvan", 9)
	Net.roster[77].at = idx
	Net.spots[77] = {"at": idx, "body": -9, "x": 0.0, "z": 0.0, "ang": 0.0, "t": t, "host": -9, "held": held, "got": Time.get_ticks_msec()}


func _no_partner() -> void:
	Net.spots.erase(77)
	Net.roster.erase(77)


## 3. Through a save.
func _through_a_save() -> void:
	var idx := _pair_of(false)
	var L := SystemLayout.of(Run.map[idx])
	var tm := 0.62 * TAU / L.pair_n
	Run.map_clock[idx] = tm
	var a := _sky_at(idx)
	var held := a.held_angle()
	var b_band := a._sun_at(SystemLayout.STAR_B)
	a.free()
	SaveGame.save()
	if not _ok("a save written", SaveGame.has_save()):
		return
	# SCRAMBLED, so nothing survives by staying put
	Run.map_clock.clear()
	Run.map_clock[idx] = 3.0
	_ok("the save read back", SaveGame.load_into_run())
	var b := _sky_at(idx)
	_ok("LOCAL after the save holds the very clock (%.6f, saved %.6f)" % [b.held_t(), tm], absf(b.held_t() - tm) < 1e-6)
	_ok("and the very angle, star B where it was on the band (%s, before %s)" % [b._sun_at(SystemLayout.STAR_B), b_band],
		absf(angle_difference(b.held_angle(), held)) < 1e-6 and b._sun_at(SystemLayout.STAR_B) == b_band)
	b.free()


## 4. One sun.
func _one_sun() -> void:
	for n: MapGen.MapNode in Run.map:
		var L := SystemLayout.of(n)
		if L.twin or n.type == MapGen.NodeType.START:
			continue
		var same := true
		for tm: float in [0.0, 333.25]:
			Run.map_clock[n.index] = tm
			var s := _sky_at(n.index)
			same = same and s._a0 == Vector2.ZERO and s._turn == 0.0 and s._sun_at(SystemLayout.STAR_B) == s._sun \
				and s.suns_depth() == 0.0
			s.free()
		Run.map_clock.erase(n.index)
		_ok("one sun (system %d): star A the band's anchor, nothing turned, at any clock" % n.index, same)
		return


func _local_sky() -> LocalSky:
	var sc := Router.current as SectorScreen
	if sc == null or sc._view == null:
		return null
	return sc._view.backdrop
