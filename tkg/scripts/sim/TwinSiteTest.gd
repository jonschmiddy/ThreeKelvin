extends Node

## STAR B IS A PLACE, AS THE ONE STAR IS (ruling 20, Oct 30: "Prototype: twin:A
## giant:A"), on the real map, headless:
##   godot --headless --fixed-fps 60 --path . -- sheet=TwinSiteTest
##
## A system with two suns (the run's ordinary system with the longest name, made
## a twin the way a harness may, `n.twin = true`), from a world round star A:
##   - star B is hit where its sun is drawn, at the size it is drawn (the
##     SunView the map puts there, `SystemView.star2`), and star A where it is;
##     a click on a sun is on it even with its world just behind it; the tip
##     names each "<system> A" / "<system> B" with its kind;
##   - each star's close orbit, drawn bigger than life to read, stays short of
##     its own world's disc, and a ship's orbit round that world off its sun;
##   - one click on star B selects it: the panel's sector page shows both suns,
##     each with its own facts and FLY HERE, and the system reads BINARY; every
##     word and button on it inside the panel and none on another (fit means
##     nothing overlaps), here and on the giant's page with its MASS line;
##   - a right-click zooms onto star B and holds it in the middle;
##   - star B's FLY HERE flies there: the status line says where it is going,
##     then CLOSE ORBIT · <system> B, and the ship rides round star B at the
##     layout's close orbit for it; its FLY HERE reads IN A CLOSE ORBIT;
##   - the map leaves the ship at star B (`Run.site_here` -4), LOCAL finds no
##     event there (star B holds none), and the map puts it back round star B;
##   - a partner in star B's close orbit is drawn where it said it was (a spot
##     at -4 is absolute, as at -1), and hidden behind star B's disc there;
##   - a ship let go round star B, or round both suns, is drawn on a wide orbit
##     round that and the words say ORBITING <system> B / BOTH STARS;
##   - a ship settled round star B, round both suns or round star A, the map
##     left for LOCAL and shown again (and the same through the save's rows),
##     comes back on that orbit: the same centre, on its radius within 1 px a
##     second on, a flight from there leaving from the ship; one sun the same;
##   - the map left on a flight's coast puts the ship where it was going, in
##     orbit there, as LOCAL is told and the flight counted (twin and one sun);
##     the map_fly hint keeps quiet on the way;
##   - the map drawn again round a flight (another rendering style or GRAPHICS
##     LOW, `_on_style`): a GO on its coast is in orbit there with its errand
##     run once and the map open; a GO still being planned flies on and its
##     errand runs on arrival; a FLY HERE on its coast opens the place; a
##     flight let go of with W is not flown again (twin and one sun);
##   - the curl the map draws for a capture into star B's close orbit is the
##     one `start_rail` flies;
##   - in either star's close orbit the words by the ship, and a selected sun's
##     name, are never written across the other sun;
##   - a partner off a world is drawn on that orbit's drawn ring, as your own
##     ship is;
##   - holding alongside to leave, the status line and the words by the ship
##     say LEAVING, not ALONGSIDE and YOU;
##   - a ship left at star B in a system with one sun comes back at the star,
##     LOCAL's sky with it;
##   - it quits with a flight plan still being made on a worker, and the quit
##     waits for it (`ShipFlight.drain`: it crashed, signal 11);
##   - the zoom the map opens at is the layout's own formula
##     (`SystemLayout.open_zoom`) on its frame, and on the real frame every
##     twin opens at or nearer than the zoom its rings were fitted to;
##   - every giant's MASS line is 1/n of its star (n the whole number nearest
##     1 / gm_frac), "OF ITS STARS" round two suns, in the FAUNA row's place so
##     the page keeps its rows;
##   - the HUD's SECTOR tab says "binary system".
## Jon's picks from the twin looks sheet (Nov 1), and "Let's call it Binary
## instead of two suns":
##   - no string a player reads says two suns or both suns (a world round the
##     pair is AROUND BOTH STARS, a ship settled round it ORBITING BOTH STARS);
##   - every system lists its SATELLITES in name order, the sector page too, one
##     sun's in the order they always were ("list:C"); and every binary's event
##     cards, above that list, in the same order;
##   - star B reads a K5's own MASS and RADIUS, 0.7 SOL, in every binary, its
##     pull as built ("starb:B");
##   - on the ring of a world round one sun the ship is drawn over that world all
##     the way round in a 1 px light outline, never on a ring round both suns or
##     one sun's ("ring:A");
##   - over the binaries of three seeds at the opening zoom, with the ship in
##     every star's close orbit and on every world's ring, with each other place
##     selected, and let go coasting into each world's ring, no word on the map
##     is written across a sun (IN ORBIT · OMEGA CALLOUS I ran across both on
##     seed 7; WILL ORBIT <world> across one in about half the coasts, a
##     selected world's name across its sun), and nearly none held back for it;
##     the ship's own words never over an event's beacon where a spot clears
##     both (stepped off the suns, IN ORBIT · OMEGA CALLOUS I covered one), and
##     where stepped, off the reticle's ticks round their place and over no
##     selected name or forecast they would hide where a spot clears it;
##   - riding OMEGA CALLOUS I's ring for two orbits, its world selected, the
##     ship's words hold still (stepped, they hopped between under the ring and
##     under the ship about twice an orbit).
## Jon's "Binary kinds: close:B share:A" (Nov 1), `_close_pairs`, over the
## binaries of seeds 7, 4242 and 1999 as rolled: about one in three a close pair,
## its suns 150 to 170 px apart, every body round both past the steady limit,
## nothing meeting (bodies, rings, the suns' keep-outs, close orbits and capture
## rings), most with a planet in the middle band, the giant round both suns in
## either kind, a ship jumping in arrived out past every world's ring (53 of 56
## not, 43 inside the first world, on d9f1afca); and the ring sweep above
## sweeps close pairs too.
## Jon's "gap:A" (Nov 1): one sun and every close pair open as they always did
## (`_opens_as_before`); a wide pair opens framed on its two suns and their own
## worlds, the wheel goes out to the whole system and a right-click comes home
## to that framing (`_wheel_and_home`); in each wide pair the ring sweep opens,
## each world round one sun drawn clear of its sun and every beacon off the
## picture marked at the frame's edge on nothing drawn (`_pair_marks`); a ship
## put back on a world round both suns is taken into the framing
## (`_put_back_framed`); a partner off the picture has its arrow too
## (`_partner_marked`). Each arrow's look (Jon, Nov 5, `_arrow_shapes`): its
## key glyph as tall as the arrow, and the arrow hollow.
## Prints how many twin systems and cases each part saw.
##
## IT JUDGES THE WHOLE BUILD. Where a part is another build's (the flight's ride
## round star B and its settle, the drawing's star B), it is checked all the
## same and fails on a tree without that build, saying whose it is: on
## feat/twin-sites alone, the ride round star B, the settle and star B's drawn
## sun fail, and nothing else.

const PanelS := preload("res://scripts/ui/sysmap/SystemPanel.gd")
const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")
const OverlayS := preload("res://scripts/ui/sysmap/SystemOverlay.gd")
const FlightS := preload("res://scripts/ui/sysmap/ShipFlight.gd")
const MapHullS := preload("res://scripts/ui/sysmap/MapHull.gd")
## THE BINARIES THE WORDS AND THE OUTLINE ARE SWEPT OVER (`_ring_sweep`), as
## each seed rolls them; `ringseeds=a,b` for others, `ringcap=N` binaries a seed
const RING_SEEDS := [7, 4242, 1999]
const RING_CAP := 10
## and always these (seed: nodes): the binary the words ran across both suns in,
## and those a selected world's name sat across its sun in (SIGMA CINDER-2 II,
## LAMBDA FALLOW II, ETA CALLOUS II; the picks review, Nov 1)
const RING_MUST := {7: [284, 46, 83], 4242: [116]}

var h := Harness.new()
## twin systems and twin cases seen, by part
var _seen := {}


func _ready() -> void:
	_run.call_deferred()


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func _saw(part: String, k: int = 1) -> void:
	_seen[part] = int(_seen.get(part, 0)) + k


## Until no ladder move is under way (headless, they swap at once).
func _idle() -> void:
	for i in 900:
		if not ZoomLadder.busy() and ZoomLadder.chain == &"":
			return
		await get_tree().process_frame


## The map, shown fresh for the system the ship is at, its ship in place.
func _map() -> SystemMapScreen:
	Router.show_system()
	await _idle()
	for i in 240:
		var m := Router.current as SystemMapScreen
		if m != null and m.flight != null and m.view.layout != null:
			await _frames(4)
			return m
		await get_tree().process_frame
	return null


func _run() -> void:
	await get_tree().process_frame
	_arrow_shapes()
	_close_pairs()
	_opens_as_before()
	h.seed_run(4242)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_fit_zooms()
	_mass_lines()
	_star_facts_all()
	_around_rows()
	_name_order_all()
	_no_two_suns_said()
	var n := _longest_twin()
	if not h._ok("an ordinary system to make a twin (%s)" % (MapGen.star_name(n) if n != null else "none"), n != null):
		_end()
		return
	n.twin = true
	Run.at = n.index
	n.visited = true
	var L := SystemLayout.of(n)
	h._ok("it is laid out with two suns", L.twin and L.stars().size() == 2)
	var wa := -1
	for b in L.bodies:
		if b.host_id == -1 and b.world != &"":
			wa = b.index
	if not h._ok("a world round star A to start from (#%d)" % wa, wa >= 0):
		_end()
		return
	SystemMapScreen._parked[n.index] = {"at": wa, "mode": &"rail"}
	var m := await _map()
	if not h._ok("the map comes up in %s" % MapGen.star_name(n), m != null and m.view.node == n):
		_end()
		return
	# (at a clock where no world's beacon is drawn over star A's middle: a beacon
	# is drawn on top and takes the click, and the clicks below are on the suns.
	# EPSILON GALLOWS SECUNDUS on seed 4242, this pick since stations were halved
	# on Nov 3, opened with its world just in front of star A and that world's
	# beacon over the sun, so the map opens again half the world's turn on)
	var over: Dictionary = m.overlay.hit(m.overlay.star_scr(-1))
	if over.get("kind", &"") == &"beacon":
		h._ok("star A's middle is under a world's beacon at %.2f s (#%d), so the map opens again half that world's turn on" % [
			m.view.t, int(over.get("body", -99))], true)
		Run.map_clock[n.index] = float(m.view.t) + L.bodies[wa].period * 0.5
		Router.show_local()
		await _idle()
		m = await _map()
		if not h._ok("the map comes up again in %s, star A's middle clear (%s)" % [MapGen.star_name(n),
				(m.overlay.hit(m.overlay.star_scr(-1)) as Dictionary).get("kind", &"") if m != null else "no map"],
				m != null and m.view.node == n
				and (m.overlay.hit(m.overlay.star_scr(-1)) as Dictionary).get("kind", &"") == &"star"):
			_end()
			return
	h._ok("the ship is put back in orbit of the world round star A (%d)" % m.flight.reached(), m.flight.reached() == wa)
	_saw("twin systems")
	await _wheel_and_home(m)
	await _ring_outline_open(m, wa)
	await _preview_end_gap(m, wa)
	_satellites_page(m)
	await _stars_as_places(m, n)
	await _fly_to_b(m, n)
	await _back_at_b(n)
	await _partner_at_b(n)
	await _partner_marked()
	await _settle_round(n)
	await _restore_round(n)
	await _labels_off_suns(n)
	await _capture_curl_b(n)
	await _mid_flight_tab(n, "twin")
	await _restyle_mid_flight(n, "twin")
	await _go_view_open(n, "twin")
	await _giant_page(n)
	await _alongside_hold()
	await _one_sun_fallback(n)
	await _ring_sweep()
	await _ring_words_ride()
	await _put_back_framed()
	await _ladder_holds_the_pair()
	await _end_planning()
	_end()


func _end() -> void:
	var keys: Array = _seen.keys()
	keys.sort()
	var parts := PackedStringArray()
	for k in keys:
		parts.append("%s %d" % [k, int(_seen[k])])
	print("  --   twin cases seen: %s" % ", ".join(parts))
	h.verdict("twinsitetest")
	get_tree().quit(h.code())


## The ordinary system that may have two suns whose "<name> B" is widest, of
## those whose binary is a wide pair: the parts after it start from its world
## round star A (a close pair has none, `_close_pairs`).
func _longest_twin() -> MapGen.MapNode:
	var font := UITheme.pixel_font()
	var best: MapGen.MapNode = null
	var best_w := -1.0
	for raw in Run.map:
		var c: MapGen.MapNode = raw
		if not MapGen.twin_ok(c) or c.region == MapGen.Region.FAUNA or c.index == Run.at or SystemLayout.is_close(c):
			continue
		var w := font.get_string_size(MapGen.star_name(c) + " B", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_HEAD).x
		if w > best_w:
			best_w = w
			best = c
	if best != null:
		print("  --   the longest name of a system that may have two suns: %s (%d px at the panel's head size)" % [MapGen.star_name(best), int(best_w)])
	return best


# ---------------------------------------------------------------- the pair framed
## ONE SUN AND A CLOSE PAIR OPEN AS THEY ALWAYS DID (Jon, Nov 1, "gap:A" is a
## wide pair's alone), over every system of CLOSE_SEEDS as rolled, laid out, on
## the layout's frame: `SystemMapScreen.open_view` is star A and exactly
## `zoom_for`, the whole system; a wide pair's is nearer, on its own part.
func _opens_as_before() -> void:
	var same := 0
	var wide := 0
	var lapped := 0
	var bad: Array[String] = []
	for sd: int in CLOSE_SEEDS:
		Rng.forced = sd
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		for raw in Run.map:
			var c: MapGen.MapNode = raw
			if c.type != MapGen.NodeType.SYSTEM and c.type != MapGen.NodeType.STATION:
				continue
			var L := SystemLayout.of(c)
			var ov := SystemMapScreen.open_view(L, c, SystemLayout.FIT_FRAME, 0.0)
			var whole := SystemMapScreen.zoom_for(L, c, SystemLayout.FIT_FRAME)
			if L.twin and not L.close:
				wide += 1
				if float(ov.zoom) <= whole * 1.5 or not L.pair_box(0.0).has_point(ov.at):
					bad.append("seed %d %s (wide): %s, whole %.4f" % [sd, MapGen.star_name(c), ov, whole])
				lapped += _framed_round_lap(L, c, ov, sd, bad)
			elif float(ov.zoom) == whole and ov.at == Vector2.ZERO and L.pair_box(0.0).size == Vector2.ZERO:
				same += 1
			else:
				bad.append("seed %d %s: %s, whole %.4f" % [sd, MapGen.star_name(c), ov, whole])
	_saw("systems opened as before", same)
	_saw("wide pairs framed at kept clocks", lapped)
	h._ok("one sun and every close pair open as they did, on star A at the whole system's zoom, and every wide pair nearer on its own part, the same at %d clocks round its lap with the pair as it stands then on the picture (%d as before, %d wide; %d not)%s" % [
		LAP_CLOCKS, same, wide, bad.size(), "" if bad.is_empty() else ": " + "; ".join(bad.slice(0, 4))], bad.is_empty() and same > 0 and wide > 0 and lapped == wide)


## A WIDE PAIR OPENED AT ANY KEPT CLOCK (ruling 23: the map keeps each
## system's clock, `Run.map_clock`, and the pair turns on it): at LAP_CLOCKS
## clocks round its lap, `open_view` frames it the same as at t 0 (on the
## balance point, no nearer than the circle it sweeps allows,
## `SystemMapScreen.pair_reach`), and the
## pair as it stands at each (both suns' discs and every world round one sun,
## its whole circle and reach) is inside the picture that frames, on the
## layout's frame. 1 where it holds, else 0 and why in `bad`. Held still
## (`-- pair=0`) every clock is the laid-out pair, as before.
const LAP_CLOCKS := 8


func _framed_round_lap(L: SystemLayout, c: MapGen.MapNode, ov0: Dictionary, sd: int, bad: Array[String]) -> int:
	var lap: float = TAU / L.pair_n if L.pair_n > 0.0 else 0.0
	var fs := SystemLayout.FIT_FRAME
	for k in LAP_CLOCKS:
		var t := 37.0 + lap * float(k) / float(LAP_CLOCKS)
		var ov := SystemMapScreen.open_view(L, c, fs, t)
		var nm := "seed %d %s at t %.0f (%.0f deg round)" % [sd, MapGen.star_name(c), t, rad_to_deg(L.pair_n * t)]
		if (ov.at as Vector2).distance_to(ov0.at) > 1e-3 or absf(float(ov.zoom) - float(ov0.zoom)) > 1e-9:
			bad.append("%s: framed at %s, %.4f, not as at t 0 (%s, %.4f)" % [nm, ov.at, ov.zoom, ov0.at, ov0.zoom])
			return 0
		var z := float(ov.zoom)
		var half := Vector2(fs.x * 0.5 / z, fs.y * 0.5 / (z * SystemLayout.SLANT))
		var win := Rect2((ov.at as Vector2) - half, half * 2.0)
		for p: int in L.stars():
			var sp := L.star_pos(p, t)
			var r := L.star_radius(p)
			if not win.encloses(Rect2(sp - Vector2(r, r), Vector2(r, r) * 2.0)):
				bad.append("%s: star %d at %s off the picture %s" % [nm, p, sp, win])
				return 0
		for b in L.bodies:
			if SystemLayout.is_star(b.host_id):
				var rr := b.orbit + SystemLayout.reach_of(b)
				if not win.encloses(Rect2(b.host_at(t) - Vector2(rr, rr), Vector2(rr, rr) * 2.0)):
					bad.append("%s: %s's circle round %s off the picture %s" % [nm, b.name, b.host_at(t), win])
					return 0
	return 1


## THE WHEEL OUT TO THE WHOLE SYSTEM AND HOME AGAIN, on this wide pair's map: it
## opened at `open_zoom`, nearer than the whole system and on its own part;
## zoomed in past that, no arrow at the edge; the wheel goes out to the whole
## system and stops there, every beacon then on the picture and none marked;
## a right-click on empty space glides back to the opening framing.
func _wheel_and_home(m: SystemMapScreen) -> void:
	var v = m.view
	var ov = m.overlay
	h._ok("this wide pair opened framed on its own part: zoom %.4f, its whole system %.4f, looking at %s (home %s)" % [v.zoom, m.zoom_min, m._look_at(), m.home_at],
		absf(v.zoom - m.open_zoom) < 1e-9 and m.open_zoom > m.zoom_min * 1.5 and m._look_at().distance_to(m.home_at) < 0.5)
	m._zoom_to = minf(v.ZOOM_MAX, m.open_zoom * 2.0)
	m._anchor = Vector2(-1, -1)
	for i in 300:
		await get_tree().process_frame
		if absf(v.zoom - m._zoom_to) < 1e-4:
			break
	await _frames(2)
	h._ok("zoomed in past the opening (%.3f), no arrows at the edge (%d)" % [v.zoom, (ov.edge_marks as Array).size()], (ov.edge_marks as Array).is_empty())
	for i in 40:
		m._zoom_by(1.0 / SystemMapScreen.ZOOM_STEP, Vector2(v.CX, v.CY))
	for i in 600:
		await get_tree().process_frame
		if absf(v.zoom - m.zoom_min) < 1e-4:
			break
	await _frames(2)
	var off := 0
	for e in ov.beacons_at:
		if not OverlayS.beacon_box(e[0]).intersects(v.window):
			off += 1
	var beacon_marks := (ov.edge_marks as Array).filter(func(e: Dictionary) -> bool: return int(e.body) != -9).size()
	h._ok("the wheel goes out to the whole system and stops there (%.4f, wanted %.4f), every beacon on the picture (%d off) and none marked (%d)" % [
		v.zoom, m.zoom_min, off, beacon_marks], absf(m._zoom_to - m.zoom_min) < 1e-6 and absf(v.zoom - m.zoom_min) < 1e-3 and off == 0 and beacon_marks == 0)
	m.right_click({})
	for i in 3000:
		await get_tree().process_frame
		if m._glide.is_empty():
			break
	await _frames(2)
	h._ok("a right-click on empty space glides back to the opening framing (zoom %.4f of %.4f, looking at %s, home %s)" % [v.zoom, m.open_zoom, m._look_at(), m.home_at],
		absf(v.zoom - m.open_zoom) < 1e-3 and m._look_at().distance_to(m.home_at) < 1.0)
	_saw("wide pairs wheeled out and home")


## A SHIP PUT BACK ON SOMETHING THAT CIRCLES BOTH SUNS, the map shown again: the
## opening framing takes it in (`SystemMapScreen.show_system`), so it is on the
## picture, its place too, and the framing is still no further out than the
## whole system. Framed on the pair alone the ship was off it, and the move
## down from LOCAL ended on nothing.
func _put_back_framed() -> void:
	Router.show_local()
	await _idle()
	await _frames(2)
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	# (the first wide pair with a world round both suns, its farthest)
	var n: MapGen.MapNode = null
	var L: SystemLayout = null
	var far := -1
	for raw in Run.map:
		var c: MapGen.MapNode = raw
		if not MapGen.twin_ok(c) or c.region == MapGen.Region.FAUNA or c.index == Run.at or SystemLayout.is_close(c):
			continue
		var was := c.twin
		c.twin = true
		var Lc := SystemLayout.of(c)
		for b in Lc.bodies:
			if b.world != &"" and b.host_id == -9 and (far < 0 or b.orbit > Lc.bodies[far].orbit):
				far = b.index
		if far >= 0:
			n = c
			L = Lc
			break
		c.twin = was
	if not h._ok("a wide pair with a world round both suns (%s, #%d)" % [MapGen.star_name(n) if n != null else "none", far], n != null):
		return
	Run.at = n.index
	n.visited = true
	SystemMapScreen._parked[n.index] = {"at": far, "mode": &"rail"}
	var m := await _map()
	if not h._ok("the map comes up with the ship at %s" % L.bodies[far].name, m != null and m.flight.reached() == far):
		return
	var v = m.view
	var wc: Vector2 = v.at[far]
	var sc: Vector2 = Vector2(v.CX, v.CY) + v.pan + m.overlay.ship_rel()
	var pair := float(SystemMapScreen.open_view(m.view.layout, n, m._frame.size, Run.map_t(n.index)).zoom)
	h._ok("put back out there, the opening framing takes it in: the place at %s and the ship at %s inside the picture %s, zoom %.3f (the pair alone %.3f, the whole system %.3f)" % [
		wc, sc, v.window, v.zoom, pair, m.zoom_min],
		v.window.grow(-8.0).has_point(wc) and v.window.grow(-4.0).has_point(sc) and v.zoom >= m.zoom_min - 1e-9 and v.zoom < pair)
	_saw("ships put back framed")


# ---------------------------------------------------------------- the close pair
## THE CLOSE PAIR (Jon, Nov 1, "Binary kinds: close:B share:A"), over the
## binaries of CLOSE_SEEDS as each rolls them, laid out, no map:
##   - about one binary in three is a close pair, the rest wide, on every seed;
##   - its suns 150 to 170 px apart, every body round both, at the balance point
##     and past 1.03 of the nearest steady orbit round the pair;
##   - nothing meets: no two bodies, no world's ring and a sun's close ring
##     (RING_GAP, one sun's rule), no sun's keep-out, close orbit or capture ring
##     and the other's;
##   - most have a planet in the middle band, where a city, a green world or an
##     ocean can be (a wide pair's are near or far);
##   - in both kinds the giant circles both suns.
## How often a body sits inside another world's ring is printed against one
## sun's, not judged (the sheet's cost: about twice as often). The words on the
## map are `_ring_sweep`'s, which counts the close pairs it saw.
const CLOSE_SEEDS := [7, 4242, 1999]


func _close_pairs() -> void:
	var n_bin := 0
	var n_close := 0
	var per_seed: Array[String] = []
	var seps: Array[float] = []
	var off_both: Array[String] = []
	var inside: Array[String] = []
	var meet: Array[String] = []
	var least := {"bodies": INF, "world ring to a sun's ring": INF, "keep-outs": INF, "close orbit to the other's keep-out": INF, "capture rings": INF}
	var mid := 0
	var hot_first := 0
	var held := [0, 0]
	var held_one := [0, 0]
	var giants := {"wide": [0, 0], "close": [0, 0]}
	var arrive_in: Array[String] = []
	var arrive_k: Array[float] = []
	var suns_px: Array[float] = []
	for sd: int in CLOSE_SEEDS:
		Rng.forced = sd
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var sb := 0
		var sc := 0
		for raw in Run.map:
			var c: MapGen.MapNode = raw
			var L := SystemLayout.of(c)
			if not L.twin:
				if c.type == MapGen.NodeType.SYSTEM and L.star == SystemLayout.StarKind.ORDINARY:
					_held_in_rings(L, held_one)
				continue
			sb += 1
			for b in L.bodies:
				if b.kind == &"giant":
					var gk: Array = giants["close" if L.close else "wide"]
					gk[0] += 1
					gk[1] += int(b.host_id == -9 and b.host0.distance_to(L.bary) < 0.01)
			if not L.close:
				continue
			sc += 1
			var at := "seed %d %s" % [sd, MapGen.star_name(c)]
			seps.append(L.sep)
			var lo := SystemLayout.p_limit(1.0 - L.star_share) * SystemLayout.P_MARGIN * L.sep
			for b in L.bodies:
				if b.host_id != -9 or b.host0.distance_to(L.bary) > 0.01:
					off_both.append("%s: %s round %d" % [at, b.name, b.host_id])
				if b.orbit < lo - 1e-6:
					inside.append("%s: %s at %.0f, the limit %.0f" % [at, b.name, b.orbit, lo])
			# nothing meets
			var g: Array = L.bodies.duplicate()
			g.sort_custom(func(x, y): return x.orbit < y.orbit)
			for i in range(1, g.size()):
				var gap: float = g[i].orbit - g[i - 1].orbit - SystemLayout.reach_of(g[i]) - SystemLayout.reach_of(g[i - 1])
				least.bodies = minf(least.bodies, gap)
				if gap <= 0.0:
					meet.append("%s: %s and %s" % [at, g[i - 1].name, g[i].name])
			for b in L.bodies:
				if b.soi <= 0.0:
					continue
				for p in L.stars():
					var d := b.orbit - b.soi - b.host0.distance_to(L.star_pos(p, 0.0)) - L.star_ring_of(p)
					least["world ring to a sun's ring"] = minf(least["world ring to a sun's ring"], d)
					if d < SystemLayout.RING_GAP - 1e-6:
						meet.append("%s: %s's ring and star %d's close ring" % [at, b.name, p])
			var ka := L.keep_clear_of(-1)
			var kb := L.keep_clear_of(SystemLayout.STAR_B)
			var pairs := {"keep-outs": L.sep - ka - kb,
				"close orbit to the other's keep-out": minf(L.sep - L.star_rail_of(-1) - kb, L.sep - L.star_rail_of(SystemLayout.STAR_B) - ka),
				"capture rings": L.sep - L.star_ring_of(-1) - L.star_ring_of(SystemLayout.STAR_B)}
			for k: String in pairs:
				least[k] = minf(least[k], pairs[k])
				if float(pairs[k]) <= 0.0:
					meet.append("%s: the suns' %s" % [at, k])
			# what it holds
			var has_mid := false
			for b in L.bodies:
				has_mid = has_mid or (b.kind == &"planet" and b.zone == 1)
			mid += int(has_mid)
			hot_first += int((g[0] as SystemLayout.Body).zone == 0)
			_held_in_rings(L, held)
			# THE SHIP ARRIVES OUT PAST EVERY WORLD, at the frame's edge as round
			# one sun (`SystemMapScreen.show_system`'s point, on the layout's
			# frame): packed close, the rings left no clear circle there, and it
			# was put inside the first world beside the suns (43 of 56 on
			# d9f1afca, the built stills)
			var z := SystemMapScreen.zoom_for(L, c, SystemLayout.FIT_FRAME)
			var fl := FlightS.new()
			fl.setup(L, Vector2(minf(L.edge, (SystemLayout.FIT_FRAME.x * 0.5 - 26.0) / z), -210.0), 40.0)
			var ar: float = (fl.f.p - L.bary).length()
			var out := 0.0
			for b in L.bodies:
				out = maxf(out, b.orbit + SystemLayout.arrive_reach(b))
			arrive_k.append(ar / (L.edge - L.bary.length()))
			if ar < out - 1e-6:
				arrive_in.append("%s at %.0f, inside %.0f" % [at, ar, out])
			# and the two suns on screen as the map opens, edge to edge
			var d2 := Vector2(L.star2_at0.x, L.star2_at0.y * SystemLayout.SLANT).length() * z
			suns_px.append(d2 - SystemLayout.sun_drawn(L.star_r, z) - SystemLayout.sun_drawn(L.star2_r, z))
		n_bin += sb
		n_close += sc
		per_seed.append("seed %d %d of %d" % [sd, sc, sb])
		h._ok("seed %d: close pairs among its binaries (%d of %d), wide pairs too" % [sd, sc, sb], sc > 0 and sc < sb)
	_saw("close pairs laid out", n_close)
	var share := float(n_close) / float(maxi(n_bin, 1))
	seps.sort()
	print("  --   close pairs: %s; the suns apart %s px; the first body hot in %d, a planet in the middle band in %d of %d" % [
		", ".join(per_seed), "%.1f to %.1f (median %.1f)" % [seps[0], seps[seps.size() - 1], seps[seps.size() / 2]] if not seps.is_empty() else "none",
		hot_first, mid, n_close])
	print("  --   least margins, px: %s" % ", ".join(least.keys().map(func(k: String) -> String: return "%s %.1f" % [k, least[k]])))
	arrive_k.sort()
	suns_px.sort()
	if not arrive_k.is_empty():
		print("  --   a close pair's arrival %.2f to %.2f of the way to the edge (median %.2f); its suns %.1f to %.1f game px apart edge to edge as the map opens (median %.1f)" % [
			arrive_k[0], arrive_k[-1], arrive_k[arrive_k.size() / 2], suns_px[0], suns_px[-1], suns_px[suns_px.size() / 2]])
	h._ok("a ship jumping into a close pair arrives out past every world's ring, at the edge as round one sun (%d of %d inside one)%s" % [
		arrive_in.size(), n_close, "" if arrive_in.is_empty() else ": " + "; ".join(arrive_in.slice(0, 4))], n_close > 0 and arrive_in.is_empty())
	print("  --   a body inside another world's ring: %d of %d round a close pair's suns (%.0f%%), %d of %d round one sun (%.0f%%; counted, not judged)" % [
		held[0], held[1], 100.0 * held[0] / maxf(held[1], 1.0), held_one[0], held_one[1], 100.0 * held_one[0] / maxf(held_one[1], 1.0)])
	h._ok("about one binary in three is a close pair over seeds %s (%d of %d, %.0f%%)" % [CLOSE_SEEDS, n_close, n_bin, share * 100.0],
		n_close > 0 and share > 0.22 and share < 0.45)
	h._ok("each close pair's suns %.0f to %.0f px apart (%d pairs)" % [SystemLayout.CLOSE_SEP_LO, SystemLayout.CLOSE_SEP_HI, seps.size()],
		not seps.is_empty() and seps[0] >= SystemLayout.CLOSE_SEP_LO - 1e-6 and seps[seps.size() - 1] <= SystemLayout.CLOSE_SEP_HI + 1e-6)
	h._ok("every body of a close pair round both suns%s, and past %.2f of the nearest steady orbit round them%s" % [
		"" if off_both.is_empty() else " (not: " + "; ".join(off_both.slice(0, 3)) + ")", SystemLayout.P_MARGIN,
		"" if inside.is_empty() else " (not: " + "; ".join(inside.slice(0, 3)) + ")"],
		n_close > 0 and off_both.is_empty() and inside.is_empty())
	h._ok("in a close pair nothing meets: bodies, a world's ring and a sun's close ring, the suns' keep-outs, close orbits and capture rings%s" % [
		"" if meet.is_empty() else ": " + "; ".join(meet.slice(0, 4))], n_close > 0 and meet.is_empty())
	h._ok("most close pairs have a planet in the middle band (%d of %d, at least two in three)" % [mid, n_close],
		n_close > 0 and mid * 3 >= n_close * 2)
	h._ok("the giant circles both suns in every binary: wide %d of %d, close %d of %d" % [giants.wide[1], giants.wide[0], giants.close[1], giants.close[0]],
		giants.wide[0] > 0 and giants.close[0] > 0 and giants.wide[1] == giants.wide[0] and giants.close[1] == giants.close[0])


## Into `t`: how many bodies of L sit inside another world's ring round the same
## centre, of how many.
static func _held_in_rings(L: SystemLayout, t: Array) -> void:
	for b in L.bodies:
		t[1] += 1
		for o in L.bodies:
			if o != b and o.soi > 0.0 and o.host0 == b.host0 and absf(o.orbit - b.orbit) < o.soi:
				t[0] += 1
				break


# ---------------------------------------------------------------- the zoom
## THE OPENING ZOOM IS THE LAYOUT'S FORMULA. `SystemMapScreen.fit_zoom_in` on
## the layout's frame is `SystemLayout.open_zoom`, for every system of the run
## (twins forced on where they may be); and on the frame the map really has,
## measured off a real map, no twin opens further out than its rings were
## fitted to (`fit_zoom`), with no job or Hellbender out to widen it.
func _fit_zooms() -> void:
	var same := 0
	var all := 0
	var twins := 0
	for raw in Run.map:
		var c: MapGen.MapNode = raw
		for two: bool in ([false, true] if MapGen.twin_ok(c) else [false]):
			var was := c.twin
			c.twin = two
			var L := SystemLayout.of(c)
			c.twin = was
			all += 1
			twins += int(L.twin)
			if SystemMapScreen.fit_zoom_in(L.edge, SystemLayout.FIT_FRAME) == SystemLayout.open_zoom(L.edge):
				same += 1
	_saw("twin layouts zoom-checked", twins)
	h._ok("the map's zoom formula on the layout's frame is `open_zoom`, in every system each way (%d of %d, %d with two suns)" % [same, all, twins],
		same == all and twins > 0)


## ON THE FRAME THE MAP HAS: every system that may have two suns, laid out with
## them, against the zoom its rings were fitted to, wherever nothing is posted
## past its edge (a job, the Hellbender: `fit_zoom`'s own rule). Also measured:
## how many open below it on the layout's own frame with nothing posted (the
## edge past what the fit allowed for, the layout's to look at).
func _real_frame(m: SystemMapScreen) -> void:
	var fs: Vector2 = m._frame.size
	var low := INF
	var low_at := ""
	var bare := INF
	var judged := 0
	var posted := 0
	var own_below := 0
	var own_low := INF
	var own_at := ""
	var off: Array[String] = []
	for raw in Run.map:
		var c: MapGen.MapNode = raw
		if not MapGen.twin_ok(c):
			continue
		var was := c.twin
		c.twin = true
		var L := SystemLayout.of(c)
		c.twin = was
		if SystemMapScreen.posted_past(L, c):
			posted += 1
			continue
		judged += 1
		var own := SystemLayout.open_zoom(L.edge) / maxf(L.fit_zoom, 0.0001)
		if own < 1.0 - 1e-9:
			own_below += 1
			if own < own_low:
				own_low = own
				own_at = MapGen.star_name(c)
		# (the edge alone fitted in this frame, which is what it opened at before)
		bare = minf(bare, SystemMapScreen.fit_zoom_in(L.edge, fs) / maxf(L.fit_zoom, 0.0001))
		var z := SystemMapScreen.zoom_for(L, c, fs)
		var k := z / maxf(L.fit_zoom, 0.0001)
		if k < low:
			low = k
			low_at = MapGen.star_name(c)
		# and the whole system still in the frame at it: the edge across, and up
		# and down at the map's slant
		if fs.x / (2.0 * z) < L.edge or fs.y / (2.0 * z * SystemLayout.SLANT) < L.edge:
			off.append(MapGen.star_name(c))
	_saw("twin layouts on the real frame", judged)
	print("  --   the map's frame is %dx%d (the layout fits to %dx%d); this map opens at %.4f, its layout was fitted at %.4f; the edge alone fitted in this frame opens twins at down to %.4f of it" % [
		int(fs.x), int(fs.y), int(SystemLayout.FIT_FRAME.x), int(SystemLayout.FIT_FRAME.y), m.zoom_min, m.view.layout.fit_zoom, bare])
	print("  --   with nothing posted, %d of %d twins' edges open below their fit_zoom even on the layout's own frame (least %.4f, %s); %d twins have a job or the Hellbender posted" % [
		own_below, judged, own_low if own_below > 0 else 1.0, own_at, posted])
	h._ok("on the real frame every twin opens at or nearer than its rings were fitted to (least %.4f of it, %s; %d twins)" % [low, low_at, judged],
		judged > 0 and low >= 1.0 - 1e-6)
	h._ok("with its whole edge still in the frame%s" % ("" if off.is_empty() else ": not " + ", ".join(off.slice(0, 4))), off.is_empty())
	# A TWIN WITH THE HELLBENDER ANCHORED THERE opens out to show it (the
	# Hellbender moved there for the check, then back)
	if Run.hellbender_alive():
		var hb_was := Run.hellbender_at
		for raw in Run.map:
			var c: MapGen.MapNode = raw
			if not MapGen.twin_ok(c) or c.index == m.view.node.index:
				continue
			var was := c.twin
			c.twin = true
			Run.hellbender_at = c.index
			var L := SystemLayout.of(c)
			var z := SystemMapScreen.zoom_for(L, c, fs)
			var wide := SystemMapScreen.fit_zoom_in(L.edge, fs)
			h._ok("with the Hellbender out past a twin's edge it opens to show it (%.4f, its fit_zoom %.4f)" % [z, L.fit_zoom],
				SystemMapScreen.posted_past(L, c) and z == wide and fs.x / (2.0 * z) >= L.edge)
			c.twin = was
			_saw("twins with the Hellbender posted")
			break
		Run.hellbender_at = hb_was
	# THIS MAP, as it opened (a map shown fresh fits before its frame is laid
	# out, on the layout's own frame; shown again, on the real one: either way)
	var L0: SystemLayout = m.view.layout
	h._ok("this map's whole system, the furthest the wheel goes, is at %.4f, at or nearer than its rings were fitted to (%.4f; the edge alone on the layout's frame %.4f, on this one %.4f)" % [
		m.zoom_min, L0.fit_zoom, SystemLayout.open_zoom(L0.edge), SystemMapScreen.fit_zoom_in(L0.edge, fs)],
		m.zoom_min >= L0.fit_zoom - 1e-6 and fs.x / (2.0 * m.zoom_min) >= L0.edge)


# ---------------------------------------------------------------- the stars
func _stars_as_places(m: SystemMapScreen, n: MapGen.MapNode) -> void:
	var ov = m.overlay
	var L: SystemLayout = m.view.layout
	var B := SystemLayout.STAR_B
	var nm_a := MapGen.star_name(n) + " A"
	var nm_b := MapGen.star_name(n) + " B"
	_real_frame(m)
	# THE SUNS AS DRAWN: where the map puts each sun's picture (`SystemView.star`,
	# and star B's `SystemView.star2`, the drawing's) and the disc it tells it to
	# draw (its radius R times its disc's zoom). The overlay's hit, tip and
	# occlusion read `star_scr` / `star_disc`, so these hold them to the drawing,
	# not to the overlay's own working of where star B should be.
	var sb: Vector2 = ov.star_scr(B)
	_drawn_suns(m)
	var want_b: Vector2 = m.view.block_round(m.view.screen(L.star_pos(SystemLayout.STAR_B, m.view.t).x, L.star_pos(SystemLayout.STAR_B, m.view.t).y))
	h._ok("star B is put where it holds still on the plane (%s, the plane's %s)" % [sb, want_b], sb == want_b)
	# THE HIT, at each star's place and size
	var hb: Dictionary = ov.hit(sb)
	h._ok("a click on star B is on star B (%s %d)" % [hb.get("kind", &""), int(hb.get("body", -99))], hb.get("kind", &"") == &"star" and int(hb.get("body", -99)) == B)
	# (at its edge on the side away from its own world, whose disc may stand
	# over the other side: there the click is the world's)
	var rim: float = ov.star_disc(B)
	var away := Vector2(1.0, 0.0)
	for b in L.bodies:
		if b.host_id == B and b.world != &"":
			away = (sb - m.view.at[b.index]).normalized()
	var he: Dictionary = ov.hit(sb + away * (maxf(8.0, rim) - 1.0))
	h._ok("and at its drawn edge, %.1f px out away from its world (%s %d)" % [maxf(8.0, rim) - 1.0, he.get("kind", &""), int(he.get("body", -99))],
		he.get("kind", &"") == &"star" and int(he.get("body", -99)) == B)
	# (where star A is drawn: the pair turns, ruling 23, and it leaves the origin)
	var ha: Dictionary = ov.hit(ov.star_scr(-1))
	h._ok("a click on star A is on star A (%d)" % int(ha.get("body", -99)), ha.get("kind", &"") == &"star" and int(ha.get("body", -99)) == -1)
	_saw("hits", 3)
	_hits_behind(m)
	# THE TIP, each star by its own name
	var tb: Array = ov.tip_lines(hb)[0]
	h._ok("star B's tip names it %s, %s (%s)" % [nm_b, ov.star_class_of(B), tb[0][0]], tb[0][0] == nm_b and tb[1][0] == ov.star_class_of(B))
	var ta: Array = ov.tip_lines(ha)[0]
	h._ok("star A's tip names it %s (%s)" % [nm_a, ta[0][0]], ta[0][0] == nm_a)
	h._ok("star B's tip says a click selects it (%s)" % tb[tb.size() - 1][0], tb[tb.size() - 1][0] == "CLICK: SELECT")
	# ONE CLICK SELECTS: the panel's sector page with both suns
	m.tap(hb)
	await _frames(3)
	h._ok("one click selects star B (%d), the panel on it (%d)" % [ov.selected, m.panel.filter], ov.selected == B and m.panel.filter == B)
	var tb2: Array = ov.tip_lines(hb)[0]
	h._ok("its tip now says a second click flies there (%s)" % tb2[tb2.size() - 1][0], tb2[tb2.size() - 1][0] == "CLICK AGAIN: FLY HERE")
	var words := _words(m.panel._box)
	h._ok("the panel says BINARY (never TWO SUNS), and names %s and %s" % [nm_a, nm_b],
		words.has("BINARY") and not words.has("TWO SUNS") and words.has(nm_a) and words.has(nm_b))
	h._ok("its picture holds both suns", m.panel._box.find_child("TwoSuns", true, false) != null
		and m.panel._box.find_child("TwoSuns", true, false).get_child_count() == 2)
	_star_facts_page(m)
	h._ok("star B's tip calls it the ORANGE DWARF it is drawn as (%s)" % tb[1][0], tb[1][0] == "ORANGE DWARF")
	var fa := _way_button(m, -1)
	var fb := _way_button(m, B)
	h._ok("FLY HERE to each (%s / %s)" % [fa.text if fa != null else "none", fb.text if fb != null else "none"],
		fa != null and fb != null and fa.text == "FLY HERE" and fb.text == "FLY HERE" and not fa.disabled and not fb.disabled)
	await _fit(m, "the sector page, star B selected")
	m.panel_back()
	await _fit(m, "the sector page, nothing selected")
	m.tap(hb)
	await _frames(2)
	# ON THE MAP: star B where it holds still, and a right-click holds it there
	var pr: Vector2 = ov.place_rel(B)
	var want_r: Vector2 = Vector2(L.star_pos(SystemLayout.STAR_B, m.view.t).x, L.star_pos(SystemLayout.STAR_B, m.view.t).y * m.view.TILT) * m.view.zoom
	h._ok("star B's place on screen, from the star (%s)" % pr, pr.distance_to(want_r) < 0.01)
	m.right_click(hb)
	var held := false
	for i in 3000:
		await get_tree().process_frame
		if m._focus_body == B and m._glide.is_empty():
			held = true
			break
	var look: Vector2 = m._look_at()
	var mid := Vector2(L.star_pos(SystemLayout.STAR_B, m.view.t).x, L.star_pos(SystemLayout.STAR_B, m.view.t).y * m.view.TILT)
	h._ok("a right-click on star B zooms onto it and holds it in the middle (%s, want %s)" % [look, mid], held and look.distance_to(mid) < 1.0)
	# AND HOLDS IT THERE AS IT MOVES (ruling 23: the pair turns): every frame for
	# two seconds of the clock, the middle of the view where star B is then,
	# however far it has gone
	var b0 := L.star_pos(SystemLayout.STAR_B, m.view.t)
	var worst := 0.0
	for i in 120:
		await get_tree().process_frame
		var bt := L.star_pos(SystemLayout.STAR_B, m.view.t)
		worst = maxf(worst, m._look_at().distance_to(Vector2(bt.x, bt.y * m.view.TILT)))
	var went := b0.distance_to(L.star_pos(SystemLayout.STAR_B, m.view.t))
	h._ok("and holds it there as the pair turns: %.2f plane px moved in 2 s, the view's middle at most %.2f px off it" % [went, worst],
		m._focus_body == B and worst < 1.0 and (went > 0.05 or L.pair_n == 0.0))
	m.right_click({})
	for i in 3000:
		await get_tree().process_frame
		if m._glide.is_empty() and m._focus_body == -9:
			break
	await _frames(4)
	h._ok("and a second one back out to the opening framing, the pair's own part (zoom %.3f of %.3f, the whole system %.3f; looking at %s, home %s)" % [
		m.view.zoom, m.open_zoom, m.zoom_min, m._look_at(), m.home_at],
		absf(m.view.zoom - m.open_zoom) < 0.002 and m._look_at().distance_to(m.home_at) < 1.0)
	_orbit_fit(m)
	# THE PARTNERS' AND YOUR SHIP'S DISC TEST: behind star B (further from the
	# viewer, on its disc) is hidden by it; in front is not
	# (star B where it is now: it has turned on since the clicks above)
	sb = ov.star_scr(B)
	var behind: Array = ov._star_occ(L.star_pos(SystemLayout.STAR_B, m.view.t) + Vector2(0.0, -2.0))
	var front: Array = ov._star_occ(L.star_pos(SystemLayout.STAR_B, m.view.t) + Vector2(0.0, 2.0))
	h._ok("a ship just behind star B is hidden by its disc, one just in front is not",
		behind.any(func(o: Array) -> bool: return o[0] == sb) and not front.any(func(o: Array) -> bool: return o[0] == sb))
	_saw("star B places", 1)


## EACH SUN IS HIT WHERE IT IS DRAWN, AT THE SIZE IT IS DRAWN: the overlay's
## point and disc for star p against the SunView the map paints it with, its
## place under its parent and its disc (R times the disc's zoom, `SunView._kd`).
## Star B's sun is the drawing's (`SystemView.star2`); a tree without it draws no
## star B at all, and that is a fail here, not a pass on the overlay's word.
func _drawn_suns(m: SystemMapScreen) -> void:
	var ov = m.overlay
	for s: int in m.view.layout.stars():
		var nm := "star A" if s == -1 else "star B"
		var sv = m.view.get("star") if s == -1 else m.view.get("star2")
		if not h._ok("%s's sun is drawn on the map%s" % [nm, "" if s == -1 else " (`SystemView.star2`, the drawing build's)"], sv is Node2D):
			continue
		var n2 := sv as Node2D
		var drawn_at: Vector2 = (n2.get_parent() as Node2D).transform * n2.position if n2.get_parent() is Node2D else n2.position
		var dr: float = float((n2.get("P") as Dictionary).get("R", 0.0)) * float(n2.get("_kd"))
		h._ok("%s is hit where its sun is drawn (%s, drawn at %s)" % [nm, ov.star_scr(s), drawn_at], (ov.star_scr(s) as Vector2).distance_to(drawn_at) < 0.01)
		h._ok("and at the size its disc is drawn (%.2f px, drawn %.2f)" % [ov.star_disc(s), dr], absf(float(ov.star_disc(s)) - dr) < 0.5)
		_saw("suns measured as drawn")


## A CLICK ON A SUN IS ON THE SUN WITH ITS WORLD JUST BEHIND IT. In a pair a world
## round one star passes 6 to 8 px from its sun's middle at the far side of its
## circle, behind the disc; its click circle took the sun's middle there. Each
## star's own world is put just behind its middle (3 px up the screen, further
## from the viewer) and just in front (3 px down), where the view puts bodies
## (`view.pos` / `view.at`) and put back at once: behind, the click is the sun's;
## in front, the world's, which is drawn over it. Then round one turn of its
## circle, every place it is behind the sun's middle.
func _hits_behind(m: SystemMapScreen) -> void:
	var ov = m.overlay
	var v = m.view
	var L: SystemLayout = v.layout
	var t0: float = v.t
	for s: int in L.stars():
		var nm := "star A" if s == -1 else "star B"
		var wi := -1
		for b in L.bodies:
			if b.host_id == s and b.world != &"":
				wi = b.index
		if not h._ok("%s has a world round it (#%d)" % [nm, wi], wi >= 0):
			continue
		var b: SystemLayout.Body = L.bodies[wi]
		var was_p: Vector2 = v.pos[wi]
		var was_a: Vector2 = v.at[wi]
		var sc: Vector2 = ov.star_scr(s)
		var dz := 3.0 / maxf(float(v.TILT) * float(v.zoom), 0.0001)
		var sp: Vector2 = L.star_pos(s, t0)
		var got := []
		for q: Vector2 in [sp + Vector2(0.0, -dz), sp + Vector2(0.0, dz)]:
			v.pos[wi] = q
			v.at[wi] = v.block_round(v.screen(q.x, q.y))
			var hh: Dictionary = ov.hit(sc)
			got.append("%s %d" % [hh.get("kind", &""), int(hh.get("body", -99))])
		# ROUND ONE TURN, 48 places
		var behind := 0
		var behind_ok := 0
		for k in 48:
			var q2: Vector2 = b.pos(t0 + b.period * float(k) / 48.0)
			v.pos[wi] = q2
			v.at[wi] = v.block_round(v.screen(q2.x, q2.y))
			if (v.at[wi] as Vector2).distance_to(sc) > maxf(v.draw_r(b), 4.0) + 3.0 or v.depth(q2) >= v.depth(sp):
				continue
			behind += 1
			var hk: Dictionary = ov.hit(sc)
			if hk.get("kind", &"") == &"star" and int(hk.get("body", -99)) == s:
				behind_ok += 1
		v.pos[wi] = was_p
		v.at[wi] = was_a
		h._ok("a click on %s with its world just behind is the sun's (%s), just in front the world's (%s)" % [nm, got[0], got[1]],
			got[0] == "star %d" % s and got[1] == "body %d" % wi)
		h._ok("and round its world's turn, %d of the %d of 48 places where it is behind the sun's middle" % [behind_ok, behind], behind_ok == behind)
		_saw("suns clicked with a world behind", 1 + behind)


## WHAT FITS ROUND A STAR OF TWO, AS DRAWN, at the opening zoom. An orbit is
## drawn bigger than life to read (`SystemOverlay._orbit_k`: the place's disc +
## 9 px at least), and in a pair that floor would reach past what is next to
## it. On this map: each star's close orbit (the layout's,
## `FlightSolve.star_orbit_r`) is drawn short of the disc of its own world by 2
## px where that world stands widest from it, and a ship's orbit round that
## world (the flight's `orbit_r`) 2 px off its sun's disc, unless it truly is
## that big. Then for every twin of the run at its fit_zoom, by the layout's own
## drawn sizes (`sun_drawn`, `world_drawn`): how many cut through before the cap
## and after, and the least room left between a close orbit and its sun.
func _orbit_fit(m: SystemMapScreen) -> void:
	var ov = m.overlay
	var v = m.view
	var L: SystemLayout = v.layout
	var z: float = v.zoom
	for s: int in L.stars():
		var nm := "star A" if s == -1 else "star B"
		var wi := -1
		for b in L.bodies:
			if b.host_id == s and b.world != &"":
				wi = b.index
		if wi < 0:
			continue
		var b: SystemLayout.Body = L.bodies[wi]
		var rail := FlightSolve.star_orbit_r(L, s)
		var drawn: float = ov._orbit_px(s, rail)
		var edge: float = b.orbit * z - float(v.draw_r(b))
		h._ok("%s's close orbit is drawn at %.2f px (it is %.2f, its disc %.2f), short of its world's disc at %.2f" % [nm, drawn, rail * z, ov.star_disc(s), edge],
			drawn <= edge - 2.0 + 0.001 or drawn <= rail * z + 0.001)
		var ride: float = m.flight.orbit_r(wi)
		var wd: float = ov._orbit_px(wi, ride)
		var off: float = b.orbit * z - float(ov.star_disc(s))
		h._ok("a ship's orbit round %s's world is drawn at %.2f px (it is %.2f, the world's disc %.2f), off its sun's disc at %.2f" % [nm, wd, ride * z, v.draw_r(b), off],
			wd <= off - 2.0 + 0.001 or wd <= ride * z + 0.001)
		_saw("orbits round a star of two, as drawn")
	# EVERY TWIN OF THE RUN, at its fit_zoom (the zoom it opens at with nothing
	# posted), by the layout's drawn sizes
	var stars := 0
	var cut_was := 0
	var cut_now := 0
	var cut_true := 0
	var out_was := 0
	var sun_was := 0
	var sun_now := 0
	var room := INF
	for raw in Run.map:
		var c: MapGen.MapNode = raw
		if not MapGen.twin_ok(c):
			continue
		var was := c.twin
		c.twin = true
		var L2 := SystemLayout.of(c)
		c.twin = was
		var fz: float = L2.fit_zoom
		for s: int in L2.stars():
			for b in L2.bodies:
				if b.host_id != s or b.world == &"":
					continue
				stars += 1
				var disc := SystemLayout.sun_drawn(L2.star_radius(s), fz)
				var wr := SystemLayout.world_drawn(b, fz)
				var rz := FlightSolve.star_orbit_r(L2, s) * fz
				var edge2 := b.orbit * fz - wr
				var old := maxf(rz, disc + OverlayS.ORBIT_MIN_PX)
				var now := rz * OverlayS.orbit_floor_k(rz, disc, edge2 - 2.0)
				cut_was += int(old > edge2)
				cut_now += int(now > edge2)
				cut_true += int(rz > edge2)
				out_was += int(old > b.orbit * fz)
				room = minf(room, now - disc)
				# (a ship's ride round the world: at most its ring times ORBIT_K)
				var wz := b.soi * FlightS.ORBIT_K * fz
				var off2 := b.orbit * fz - disc
				sun_was += int(maxf(wz, wr + OverlayS.ORBIT_MIN_PX) > off2)
				sun_now += int(wz * OverlayS.orbit_floor_k(wz, wr, off2 - 2.0) > off2)
	print("  --   %d stars of two with a world round them, at fit_zoom: a close orbit drawn into its world's disc %d before the cap (%d outside the world's orbit), %d now, %d as big as it truly is; the least room between a close orbit as drawn and its sun %.2f px; a ship's orbit round the world onto its sun %d before, %d now" % [
		stars, cut_was, out_was, cut_now, cut_true, room, sun_was, sun_now])
	h._ok("over every twin of the run, a close orbit is drawn into its world's disc only where it truly is that big (%d, %d; of %d) and no ship's orbit round a world onto its sun (%d)" % [cut_now, cut_true, stars, sun_now],
		stars > 0 and cut_now == cut_true and sun_now == 0)
	_saw("stars of two with a world, at fit_zoom", stars)


## THE ROW `_way_there` built for place i, and its button.
func _way_button(m: SystemMapScreen, i: int) -> Button:
	var row: Node = m.panel._box.find_child(PanelS.way_name(i), true, false)
	if row == null:
		return null
	for c in row.get_children():
		if c is Button:
			return c
	return null


## The keys of the page's fact rows (`SystemPanel._row`: a key, a spacer, a
## value), in order.
func _fact_keys(box: Node) -> Array[String]:
	var out: Array[String] = []
	for c in box.get_children():
		if c is HBoxContainer and c.get_child_count() == 3 and c.get_child(0) is Label and c.get_child(2) is Label:
			out.append((c.get_child(0) as Label).text)
	return out


## Every word on the panel's page, labels and buttons.
func _words(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for c in root.get_children():
		if c is Label and (c as Label).is_visible_in_tree():
			out.append((c as Label).text)
		elif c is Button and (c as Button).is_visible_in_tree():
			out.append((c as Button).text)
		out.append_array(_words(c))
	return out


# ---------------------------------------------------------------- fit
## FIT MEANS NOTHING OVERLAPS: the page as it stands at the panel's real size.
## It asks for no more width than the panel's text column (else, with the
## scroll bar up, the panel widens and the map frame narrows); every one-line
## label's words fit its own box; every word and button is inside the page; and
## no two of them meet.
func _fit(m: SystemMapScreen, tag: String) -> void:
	await _frames(3)
	var box: VBoxContainer = m.panel._box
	var col := box.get_global_rect()
	# THE PAGE'S OWN ROWS (the head, its facts and ways in: what this build
	# adds), each no wider than the text column; and the event cards under them
	# (a card naming the world you orbit asked for 231 px of the 226, its tags
	# and YOU · <place> on one row; that row now wraps, Nov 1)
	var mw := 0.0
	var wide: Array[String] = []
	var card_w := 0.0
	var card_said := ""
	for c in box.get_children():
		if not (c is Control and (c as Control).is_visible_in_tree()):
			continue
		var w := (c as Control).get_combined_minimum_size().x
		if c.has_method(&"set_doomed"):
			if w > card_w:
				card_w = w
				card_said = " / ".join(_words(c).slice(0, 4))
			continue
		mw = maxf(mw, w)
		if w > PanelS.TEXT_W + 0.5:
			var said := " / ".join(_words(c).slice(0, 4)) if c.get_child_count() > 0 else _say(c)
			wide.append("%s %.0f px: %s" % [c.get_class(), w, said])
	h._ok("%s: its rows ask for %.0f px, the column is %d%s" % [tag, mw, PanelS.TEXT_W, "" if wide.is_empty() else " (" + "; ".join(wide) + ")"],
		mw <= PanelS.TEXT_W + 0.5)
	h._ok("%s: its widest event card asks for %.0f px, the column is %d (%s)" % [tag, card_w, PanelS.TEXT_W, card_said],
		card_w <= PanelS.TEXT_W + 0.5)
	print("  --   %s: the panel is %d px wide, the map's frame %d px, the scroll bar %s" % [tag, int(m.panel.get_global_rect().size.x),
		int(m._frame.size.x), "up" if m.panel._scroll.get_v_scroll_bar().is_visible_in_tree() else "down"])
	var leaves := _leaves(box, [])
	var bad: Array[String] = []
	for e: Array in leaves:
		var c: Control = e[0]
		var r: Rect2 = e[1]
		if r.position.x < col.position.x - 0.5 or r.end.x > col.end.x + 0.5:
			bad.append("\"%s\" %s outside the column" % [_say(c), r])
		if e[2] > r.size.x + 0.5 and not (c is Label and (c as Label).clip_text):
			bad.append("\"%s\" is %.0f px in a %.0f px box" % [_say(c), e[2], r.size.x])
	for i in leaves.size():
		for j in range(i + 1, leaves.size()):
			var a: Rect2 = leaves[i][1]
			var b: Rect2 = leaves[j][1]
			if a.intersection(b).has_area() and not (leaves[i][0] as Node).is_ancestor_of(leaves[j][0]) and not (leaves[j][0] as Node).is_ancestor_of(leaves[i][0]):
				bad.append("\"%s\" on \"%s\"" % [_say(leaves[i][0]), _say(leaves[j][0])])
	h._ok("%s: %d words and buttons, none outside the panel or on another%s" % [tag, leaves.size(),
		"" if bad.is_empty() else ": " + "; ".join(bad.slice(0, 6))], bad.is_empty() and leaves.size() > 0)
	_saw("panel pages box-tested")


func _say(c: Control) -> String:
	if c.get("text") != null:
		return String(c.get("text")).substr(0, 28)
	return c.name


## Every showing word and button under `root`, as [control, the box its words
## or itself take, how wide its words are on one line (0 for wrapped ones)].
func _leaves(root: Node, out: Array) -> Array:
	for c in root.get_children():
		if not c is Control or not (c as Control).is_visible_in_tree():
			continue
		var k := c as Control
		var r := k.get_global_rect()
		if k is Label and (k as Label).text != "":
			var l := k as Label
			var w := l.get_theme_font(&"font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size(&"font_size")).x
			if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
				var x := r.position.x
				if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
					x = r.end.x - minf(w, r.size.x)
				elif l.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
					x = r.position.x + (r.size.x - minf(w, r.size.x)) * 0.5
				out.append([k, Rect2(x, r.position.y, minf(w, r.size.x), r.size.y), w])
			else:
				out.append([k, r, 0.0])
		elif k is RichTextLabel and (k as RichTextLabel).get_parsed_text() != "":
			out.append([k, r, 0.0])
		elif k is BaseButton:
			out.append([k, r, 0.0])
			continue
		elif String(k.name) == "TwoSuns":
			out.append([k, r, 0.0])
			continue
		_leaves(k, out)
	return out


# ---------------------------------------------------------------- the flight
## STAR B'S FLY HERE, pressed: the flight there, its words, and the orbit.
func _fly_to_b(m: SystemMapScreen, n: MapGen.MapNode) -> void:
	var B := SystemLayout.STAR_B
	var ov = m.overlay
	var nm_b := MapGen.star_name(n) + " B"
	for i in 600:
		if m.flight.can_fly():
			break
		await get_tree().process_frame
	var fb := _way_button(m, B)
	if not h._ok("star B's FLY HERE is there to press", fb != null and not fb.disabled):
		return
	fb.pressed.emit()
	var said := {}
	var landed := false
	# (a flight to a world takes up to about 30 s of map time and its ride up to
	# 4.4 s more, ruling 20's solved flight: 3600 frames at --fixed-fps 60 is a
	# minute of it)
	for i in 3600:
		await get_tree().process_frame
		said[String(ov.ship_status()[0])] = true
		if m.flight.reached() == B and m.flight.can_fly():
			landed = true
			break
	var going := "TO A CLOSE ORBIT OF " + nm_b
	h._ok("on the way the status line says where (%s)" % going, said.has(going) or said.has("LEAVING ORBIT · " + going))
	if not h._ok("the ship arrives in star B's close orbit (%d)" % m.flight.reached(), landed):
		return
	await _frames(4)
	var st: String = ov.ship_status()[0]
	h._ok("the status line says CLOSE ORBIT · %s (%s)" % [nm_b, st], st == "CLOSE ORBIT · " + nm_b)
	_round_b(m, "it rides")
	var fb2 := _way_button(m, B)
	var fa2 := _way_button(m, -1)
	h._ok("star B's FLY HERE reads IN A CLOSE ORBIT, greyed (%s); star A's FLY HERE (%s)" % [fb2.text if fb2 != null else "none", fa2.text if fa2 != null else "none"],
		fb2 != null and fb2.text == "IN A CLOSE ORBIT" and fb2.disabled and fa2 != null and fa2.text == "FLY HERE")
	await _fit(m, "the sector page, in star B's close orbit")
	h._ok("the ship's place as LOCAL is told it is star B (%d)" % m.ship_place(), m.ship_place() == B)
	# THE HUD's SECTOR tab says it is a binary system (Jon, Nov 1: "Let's call it
	# Binary instead of two suns")
	Router.hud.refresh()
	var tip := String(Router.hud._tab_system.tooltip_text).replace("\n", " ")
	h._ok("the SECTOR tab says binary, not two suns (%s)" % tip.strip_edges(), tip.contains("binary system") and not tip.to_lower().contains("two suns"))
	_saw("flights to star B")


## Left there by the map: LOCAL at star B, then the map again puts it back.
func _back_at_b(n: MapGen.MapNode) -> void:
	var B := SystemLayout.STAR_B
	Router.show_local()
	await _idle()
	await _frames(6)
	h._ok("the map left the ship at star B (site %d)" % Run.site_here(n), Run.site_here(n) == B)
	h._ok("nothing there to take (star B holds no event): %d, auto-open %d" % [SectorScreen.things_here(n).size(), LocalEventDrawer.auto_open(n)],
		SectorScreen.things_here(n).is_empty() and LocalEventDrawer.auto_open(n) == -1)
	var m := await _map()
	h._ok("the map puts it back in star B's close orbit (%d)" % (m.flight.reached() if m != null else -99), m != null and m.flight.reached() == B)
	if m != null:
		_round_b(m, "put back, it rides")
	_saw("returns to star B")


## WHERE THE SHIP IS, IN STAR B'S CLOSE ORBIT: measured on the plane from star
## B's own place, against the layout's close orbit for it
## (`FlightSolve.star_orbit_r`, its rail in a twin), not the flight's own idea
## of either. `reached() == STAR_B` alone passed with the ship riding star A.
## The ride is the flight build's (`ShipFlight.center` / `orbit_r` for star B):
## on a tree without it this fails, as it should.
func _round_b(m: SystemMapScreen, what: String) -> void:
	var L: SystemLayout = m.view.layout
	var B := SystemLayout.STAR_B
	var p3: Vector3 = m.flight.where3()
	var p := Vector2(p3.x, p3.z)
	var want := FlightSolve.star_orbit_r(L, B)
	var c3: Vector3 = m.flight.center(B, m.view.t)
	h._ok("%s round star B: %.1f px from it, its close orbit %.1f (%.1f from star A; ShipFlight.center(STAR_B) %s, the flight build's)" % [
		what, p.distance_to(L.star_pos(SystemLayout.STAR_B, m.view.t)), want, p.length(), Vector2(c3.x, c3.z)], absf(p.distance_to(L.star_pos(SystemLayout.STAR_B, m.view.t)) - want) < 3.0)


## A PARTNER IN STAR B'S CLOSE ORBIT, as the wire brings it (PROTOCOL 14): the
## offset from star B, said by a machine whose map clock is 5 s behind this
## one's, drawn on star B where it is here; a partner off a world, off that world.
func _partner_at_b(n: MapGen.MapNode) -> void:
	var m := Router.current as SystemMapScreen
	if m == null:
		h._fail("no map for the partner")
		return
	var B := SystemLayout.STAR_B
	var L: SystemLayout = m.view.layout
	# (the sender's ship on B's rail at its own clock, said off B there)
	var t_them: float = m.view.t - 5.0
	var off := Vector2(L.star_rail_of(B), 0.0)
	var sent := NetSession.spot_anchor(L, B, B, t_them) + off - NetSession.spot_anchor(L, B, B, t_them)
	var at := L.star_pos(SystemLayout.STAR_B, m.view.t) + off
	var w := 0
	for b in L.bodies:
		if b.world != &"":
			w = b.index
			break
	var ids := [70001, 70002]
	Net.roster[ids[0]] = {"id": ids[0], "at": n.index, "order": 90, "name": "Mercer"}
	Net.roster[ids[1]] = {"id": ids[1], "at": n.index, "order": 91, "name": "Kevin"}
	Net.spots[ids[0]] = {"at": n.index, "body": B, "x": sent.x, "z": sent.y, "ang": 0.5, "t": t_them, "host": B}
	Net.spots[ids[1]] = {"at": n.index, "body": w, "x": 6.0, "z": -2.0, "ang": 0.0}
	var got := {}
	for e: Array in m.partner_points():
		got[int(e[0])] = e[1]
	var c3: Vector3 = m.flight.center(w, m.view.t)
	h._ok("a partner in star B's close orbit, its clock 5 s behind, is drawn on star B as it is here (%s, want %s; B moved %.2f px in those 5 s)" % [
		got.get(ids[0], "none"), at, L.star_pos(B, t_them).distance_to(L.star_pos(B, m.view.t))],
		got.has(ids[0]) and (got[ids[0]] as Vector2).distance_to(at) < 0.01)
	h._ok("and one off a world, off that world as it is here", got.has(ids[1])
		and (got[ids[1]] as Vector2).distance_to(Vector2(c3.x, c3.z) + Vector2(6.0, -2.0)) < 0.01)
	# DRAWN ON THAT ORBIT AS IT IS DRAWN (`SystemOverlay._orbit_k`), as your own
	# ship is: at its true offset it sat on the world's disc (the seams review)
	await _frames(2)
	var ov = m.overlay
	var drawn := Vector2.INF
	for e2: Array in ov.partner_at:
		if int(e2[0]) == ids[1]:
			drawn = e2[1]
	var bw: Vector2 = ov._body_scr(w)
	var kw: float = ov._orbit_k(w, Vector2(6.0, -2.0).length())
	var want_w: Vector2 = (bw + (ov._scr(c3.x + 6.0, c3.z - 2.0) - bw) * kw).round()
	h._ok("and drawn on the world's orbit as drawn, %.2f times life (at %s, the ring's point %s, the world %s)" % [kw, drawn, want_w, bw],
		drawn != Vector2.INF and drawn.distance_to(want_w) <= 1.0)
	for id in ids:
		Net.roster.erase(id)
		Net.spots.erase(id)
	_saw("partners at star B")


## A PARTNER OFF THE PICTURE HAS ITS ARROW AT THE EDGE, as your ship and the
## events' beacons do (`SystemOverlay._draw_edge_marks`): this wide pair at its
## opening framing, a partner out in open space round both suns, below the
## balance point most of the way to the edge.
## The whole-system view kept every partner on the picture; framed on the pair,
## 15 of seed 7's 16 such were nowhere (the gap:A review). The arrow in the
## party's colour, inside the frame, and off the partner's own hull.
func _partner_marked() -> void:
	var m := Router.current as SystemMapScreen
	if m == null:
		h._fail("no map for the partner's arrow")
		return
	var L: SystemLayout = m.view.layout
	# (out to the side of the balance point the framing centres on: straight down
	# the screen 0.85 of the edge out stood just inside the picture once a
	# turning pair is framed on its balance point, `SystemMapScreen.open_view`)
	var at := L.bary + Vector2(0.85 * (L.edge - L.bary.length()), 0.0)
	var id := 70003
	Net.roster[id] = {"id": id, "at": m.view.node.index, "order": 92, "name": "Geno"}
	Net.spots[id] = {"at": m.view.node.index, "body": -9, "x": at.x, "z": at.y, "ang": 0.0}
	m._glide = {}
	m._focus_body = -9
	m._homing = false
	m._locked = false
	m._zoom_to = m.open_zoom
	m.view.zoom = m.open_zoom
	m.view.pan = -m.home_at * m.open_zoom
	await _frames(4)
	var ov = m.overlay
	var win: Rect2 = m.view.window
	var drawn := Vector2.INF
	for e: Array in ov.partner_at:
		if int(e[0]) == id:
			drawn = e[1]
	var mark: Dictionary = {}
	for mk: Dictionary in ov.edge_marks:
		if int(mk.get("peer", 0)) == id:
			mark = mk
	var off: bool = drawn != Vector2.INF and not win.grow(-2.0).has_point(drawn)
	h._ok("at the opening framing (%.3f), a partner out round both suns at %s is off the picture (drawn at %s, the picture %s)" % [m.view.zoom, at, drawn, win], off)
	if off:
		var mb: Rect2 = mark.get("box", Rect2())
		h._ok("and has its arrow at the frame's edge, with no glyph%s" % ("" if mark.is_empty() else " (at %s, pointing %s)" % [mark.at, mark.dir]),
			not mark.is_empty() and win.encloses(mb) and StringName(mark.get("glyph", &"")) == &"")
	Net.roster.erase(id)
	Net.spots.erase(id)
	await _frames(2)
	_saw("partners marked off the picture")


## LET GO ROUND STAR B, AND ROUND BOTH STARS: the wide orbit is drawn round what
## the flight settles round (`SystemOverlay._star_c`, from the flight's own
## settle centre, `ShipFlight.f.cen`), and the status line names it (from
## `f.cen_id`). It read `ShipFlight.star_orbit_c`, which the flight never built,
## and so drew and named every wide orbit round star A. First the names alone,
## from each centre; then the flight's settle (`ShipFlight.settle_at`, the
## flight build's: on a tree without it this fails, as it should), at a point
## inside star B's steady zone on the far side from its world, and at one out
## between the suns' zones and the worlds round both.
func _settle_round(n: MapGen.MapNode) -> void:
	var m := Router.current as SystemMapScreen
	if m == null:
		h._fail("no map for the settle")
		return
	var ov = m.overlay
	var L: SystemLayout = m.view.layout
	var B := SystemLayout.STAR_B
	var nm_a := MapGen.star_name(n) + " A"
	var nm_b := MapGen.star_name(n) + " B"
	# (named by what each circles, `SystemOverlay._settle_id`, never by where its
	# centre is: a turning pair's suns move off any point kept, ruling 23)
	var said := [ov._settle_nm(-1), ov._settle_nm(B), ov._settle_nm(-9)]
	h._ok("a wide orbit round star A, star B and the balance point is named %s" % " / ".join(said),
		said[0] == nm_a and said[1] == nm_b and said[2] == "BOTH STARS")
	if not h._ok("the flight can let a ship go to settle where it is (`ShipFlight.settle_at`, the flight build's)", m.flight.has_method(&"settle_at")):
		return
	var away := Vector2(1.0, 0.0)
	for b in L.bodies:
		if b.host_id == B and b.world != &"":
			away = (L.star_pos(SystemLayout.STAR_B, m.view.t) - b.pos(m.view.t)).normalized()
	var zone_b := SystemLayout.s_limit(L.star_share) * L.sep
	var r_b := (L.star_ring_of(B) + zone_b) * 0.5
	# (the pair as it stands at the map's t: it turns, ruling 23, so "across the
	# pair" is off the line between the suns where they are, and each case's
	# centre is named by its id and read again where it is once the frames have
	# run, a turning sun having moved meanwhile)
	var t0: float = m.view.t
	var side := (L.star_pos(B, t0) - L.star_pos(-1, t0)).normalized().orthogonal()
	var cases := [
		[L.star_pos(B, t0) + away * r_b, "ORBITING " + nm_b, B],
		[L.bary + side * L.sep * 1.3, "ORBITING BOTH STARS", -9],
	]
	for c: Array in cases:
		var cid := int(c[2])
		m.flight.call(&"settle_at", m.view.t, c[0], 1.0)
		var from: float = (c[0] as Vector2).distance_to(L.bary if cid == -9 else L.star_pos(cid, m.view.t))
		await _frames(12)
		var st: String = ov.ship_status()[0]
		var sc: Vector2 = ov._star_c
		var want: Vector2 = L.bary if cid == -9 else L.star_pos(cid, m.view.t)
		h._ok("let go %.0f px from %s, it settles round it: the status line says %s (%s), its wide orbit drawn round %s (%s), the flight's centre %s (%d)" % [
			from, "star B" if cid == B else "the balance point", c[1], st, want, sc, m.flight.f.cen, int(m.flight.f.cen_id)],
			m.flight.star_orbiting() and st == c[1] and sc.distance_to(want) < 0.5 and int(m.flight.f.cen_id) == cid
			and (m.flight.f.cen as Vector2).distance_to(want) < 0.01)
		_saw("wide orbits round star B or both")
	await _settled_as_b_moves(m, cases[0][0], nm_b)


## SETTLED ROUND STAR B AS IT MOVES (ruling 23): let go round star B, the clock
## running for two seconds as the pair turns, every frame the status line and
## the words by the ship say ORBITING <system> B (`SystemOverlay._settle_id`,
## by the flight's `f.cen_id`), and the wide orbit is drawn round star B where
## it is that frame (`_star_c`), on its disc (`_ring_c`, star B's place on the
## grid). Named by where its centre was kept, a ship round star B drifted to
## ORBITING BOTH STARS within seconds of the pair turning. Then broken away, the
## orbit left fades round star B (`_left`, by id).
func _settled_as_b_moves(m: SystemMapScreen, p: Vector2, nm_b: String) -> void:
	var ov = m.overlay
	var L: SystemLayout = m.view.layout
	var B := SystemLayout.STAR_B
	m.flight.call(&"settle_at", m.view.t, p, 1.0)
	await _frames(6)
	if not h._ok("let go round star B to watch it move, the flight settles round it (%d, the flight build's)" % int(m.flight.f.cen_id),
			m.flight.star_orbiting() and int(m.flight.f.cen_id) == B):
		return
	var b0 := L.star_pos(B, m.view.t)
	var frames := 0
	var named := 0
	var off := 0.0
	var ring_off := 0.0
	for i in 120:
		await get_tree().process_frame
		if not m.flight.star_orbiting():
			continue
		frames += 1
		named += int(String(ov.ship_status()[0]) == "ORBITING " + nm_b and ov._settle_id() == B)
		off = maxf(off, (ov._star_c as Vector2).distance_to(L.star_pos(B, m.view.t)))
		ring_off = maxf(ring_off, (ov._ring_c(B, ov._star_c) as Vector2).distance_to(ov.star_scr(B)))
	var went := b0.distance_to(L.star_pos(B, m.view.t))
	h._ok("settled round star B as it moves %.2f px in 2 s: named ORBITING %s in %d of %d frames, the orbit drawn round it (at most %.3f px off it, %.1f px off its disc)" % [
		went, nm_b, named, frames, off, ring_off], frames >= 100 and named == frames and off < 0.01 and ring_off < 0.01 and (went > 0.05 or L.pair_n == 0.0))
	# BROKEN AWAY by W held: the orbit left fades round star B, by its id (the
	# first frame it is off it: a ship let go by star B may be taken into its
	# close orbit a moment on, and that fade is the close orbit's)
	ov._left = {}
	var keys_were: bool = m.harness_keys
	m.harness_keys = true
	m._wasd["w"] = true
	var left := {}
	for i in 60:
		await get_tree().process_frame
		if (ov._left as Dictionary).has("id"):
			left = (ov._left as Dictionary).duplicate()
			break
	m._wasd["w"] = false
	m.harness_keys = keys_were
	h._ok("broken away, the orbit left fades round star B (%s)" % left, int(left.get("id", -99)) == B and int(left.get("body", -99)) == B)
	_saw("settled round a moving star B, frames", frames)


## PUT BACK ON THE WIDE ORBIT IT WAS SETTLED ON: round star B, round both suns
## and round star A (the way round the worlds do not go, to see it kept), the
## map left for LOCAL and shown again, and again with the record through the
## save's own rows (`SaveGame._parked_to` / `_parked_from`, JSON and back). The
## same centre and way round, on its radius within 1 px then and a second on,
## the status line naming it, and a flight from there leaving from the ship
## (`ShipFlight._dep_of`). Put back with only its point it kept the arrival
## orbit `setup` makes, round the balance point, and was pulled onto that
## radius round its own star: round B at 68 px, back on a 314 px ring that ran
## inside star A's keep-out (the seams and saves reviews, Oct 31).
func _restore_round(n: MapGen.MapNode) -> void:
	var m := Router.current as SystemMapScreen
	if m == null:
		h._fail("no map for the put-back")
		return
	var L: SystemLayout = m.view.layout
	var B := SystemLayout.STAR_B
	var away_b := Vector2(1.0, 0.0)
	var away_a := Vector2(-1.0, 0.0)
	# (each sun where it is at the map's t: star A is at the origin only as the
	# pair was laid out, ruling 23)
	var t0: float = m.view.t
	var sa := L.star_pos(-1, t0)
	var sb := L.star_pos(B, t0)
	for b in L.bodies:
		if b.world == &"":
			continue
		if b.host_id == B:
			away_b = (sb - b.pos(t0)).normalized()
		elif b.host_id == -1:
			away_a = (sa - b.pos(t0)).normalized()
	var r_b := (L.star_ring_of(B) + SystemLayout.s_limit(L.star_share) * L.sep) * 0.5
	var r_a := (L.star_ring_of(-1) + SystemLayout.s_limit(1.0 - L.star_share) * L.sep) * 0.5
	var side := (sb - sa).normalized().orthogonal()
	var cases := [[sb + away_b * r_b, B, "star B"], [L.bary + side * L.sep * 1.3, -9, "both suns"], [sa + away_a * r_a, -1, "star A"]]
	for c: Array in cases:
		for how: String in ["LOCAL", "the save's rows"]:
			await _put_back(n, c[0], int(c[1]), "%s, by %s" % [c[2], how], how != "LOCAL")
	_saw("wide orbits put back")


## One put-back (`_restore_round`): settled at p (round `want`), away and back.
func _put_back(n: MapGen.MapNode, p: Vector2, want: int, what: String, rows: bool) -> void:
	var m := Router.current as SystemMapScreen
	if m == null:
		m = await _map()
	if m == null:
		h._fail("no map for %s" % what)
		return
	m.flight.settle_at(m.view.t, p, -1.0)
	await _frames(6)
	var f0 = m.flight.f
	var cen0 := int(f0.cen_id)
	var r0: float = f0.orbit_r
	if not h._ok("%s: settled round %d at %.1f px" % [what, cen0, r0], m.flight.star_orbiting() and (want == -9 or cen0 == want)):
		return
	# (the pair's angle as the map is left, its clock kept with the ship,
	# `Run.map_clock`, and where the ship is round the centre it circles)
	var L0: SystemLayout = m.view.layout
	var ang0 := L0.pair_angle(m.view.t)
	var rel0: Vector2 = (f0.p as Vector2) - (f0.cen as Vector2)
	Router.show_local()
	await _idle()
	await _frames(4)
	if rows:
		var raw = JSON.parse_string(JSON.stringify(SaveGame._parked_to()))
		SystemMapScreen._parked = SaveGame._parked_from(raw, Run.map.size())
		var raw_c = JSON.parse_string(JSON.stringify(SaveGame._clocks_to()))
		Run.map_clock = SaveGame._clocks_from(raw_c, Run.map.size())
	m = await _map()
	if m == null:
		h._fail("no map back for %s" % what)
		return
	var f1 = m.flight.f
	var off0: float = absf(((f1.p as Vector2) - (f1.cen as Vector2)).length() - float(f1.orbit_r))
	# (back at the kept clock: the pair turned on only by the few frames the map
	# has run since it opened again, the ship where it was round its centre
	# less what it rode round meanwhile, and the centre where it is at the map's
	# t, a turning sun's)
	var L1: SystemLayout = m.view.layout
	var c_now: Vector2 = L1.bary if cen0 == -9 else L1.star_pos(cen0, m.view.t)
	# (read now: `f1` is the flight's own state, which the frames below move on)
	var cen_off := (f1.cen as Vector2).distance_to(c_now)
	var dang := absf(wrapf(L1.pair_angle(m.view.t) - ang0, -PI, PI))
	var dang_max := absf(L1.pair_n) * 0.5 + 1e-6
	var rel1: Vector2 = (f1.p as Vector2) - (f1.cen as Vector2)
	var rode := absf(wrapf(rel1.angle() - rel0.angle(), -PI, PI))
	var rode_max := float(m.flight.star_pace(r0, float(f1.cen_share))) / maxf(r0, 1.0) * 0.5 + 1e-3
	var st: String = m.overlay.ship_status()[0]
	await _frames(60)
	var f2 = m.flight.f
	var off1: float = absf(((f2.p as Vector2) - (f2.cen as Vector2)).length() - float(f2.orbit_r))
	var dep: Dictionary = m.flight._dep_of(m.view.t)
	var dp := Vector2.INF
	if StringName(dep.get("kind", &"")) == &"ring" and int(dep.get("place", 0)) == -9:
		dp = (dep.c as Vector2) + Vector2(cos(float(dep.ang)), sin(float(dep.ang))) * float(dep.rt)
	var nm: String = m.overlay._settle_nm(cen0)
	h._ok("%s: put back round %d (was %d) at %.1f px (was %.1f), %s, %.2f px off it then and %.2f a second on, going the same way (%.0f); it says %s; a flight leaves %.2f px from the ship; its centre %.3f px from where it is at the map's t; the pair turned %.5f rad from where it was left (at most %.5f), the ship %.4f rad round its centre (at most %.4f)" % [
		what, int(f1.cen_id), cen0, float(f1.orbit_r), r0, "settled" if m.flight.star_orbiting() else "NOT settled", off0, off1, float(f1.sense), st,
		dp.distance_to(f2.p) if dp != Vector2.INF else INF, cen_off, dang, dang_max, rode, rode_max],
		m.flight.star_orbiting() and int(f1.cen_id) == cen0 and cen_off < 0.01 and absf(float(f1.orbit_r) - r0) < 1.0
		and dang <= dang_max and rode <= rode_max
		and off0 < 1.0 and off1 < 1.0 and float(f1.sense) == -1.0 and st == "ORBITING " + nm and dp != Vector2.INF and dp.distance_to(f2.p) < 1.0)


## NEVER WRITTEN ACROSS THE OTHER SUN: in each star's close orbit, at the
## opening zoom, the words by the ship ("CLOSE ORBIT · <system> A/B") and the
## other star's name when it is selected, their boxes as placed
## (`SystemOverlay.label_rects`) against the other sun's disc. In this system
## the words in star B's close orbit sat 10 px over star A's disc, its whole
## radius (the words review, Oct 31).
func _labels_off_suns(n: MapGen.MapNode) -> void:
	var B := SystemLayout.STAR_B
	for at: int in [B, -1]:
		# (the map up put away, and out of the tree, before its record is set)
		Router.show_local()
		await _idle()
		await _frames(2)
		SystemMapScreen._parked[n.index] = {"at": at, "mode": &"rail"}
		var m := await _map()
		if m == null:
			h._fail("no map for the words")
			return
		var ov = m.overlay
		var other := -1 if at == B else B
		await _frames(4)
		var words: String = "CLOSE ORBIT · " + ov.star_name_of(at)
		var box := _said_box(ov, words)
		h._ok("in %s's close orbit the words by the ship are drawn (%s) clear of %s's disc (%s, r %.1f)%s" % [
			ov.star_name_of(at), box, ov.star_name_of(other), ov.star_scr(other), ov.star_disc(other),
			"" if box.size.x > 0.0 else " -- placed: %s, the ship at %d" % [ov.label_says, m.flight.reached()]],
			box.size.x > 0.0 and not _box_on_disc(box, ov.star_scr(other), ov.star_disc(other)))
		ov.selected = other
		await _frames(3)
		var nm: String = ov.star_name_of(other)
		var nb := _said_box(ov, nm)
		# (not drawn at all is a name a higher label took the place of: no overlap)
		h._ok("and %s, selected, has its name %s clear of %s's disc" % [nm, "drawn (%s)" % nb if nb.size.x > 0.0 else "held back under a higher label,", ov.star_name_of(at)],
			not _box_on_disc(nb, ov.star_scr(at), ov.star_disc(at)) or nb.size.x <= 0.0)
		ov.selected = -2
	_saw("words kept off the suns", 4)


## A point r from star A, from angle a0 on, clear of every world's ring and
## every place's reach for the next few seconds (a settle there is not taken).
func _clear_at(m: SystemMapScreen, r: float, a0: float) -> Vector2:
	var L: SystemLayout = m.view.layout
	for k in 24:
		var a := a0 + float(k) * TAU / 24.0
		var p := Vector2(cos(a), sin(a)) * r
		var clear := true
		for b in L.bodies:
			for dt: float in [0.0, 2.0, 4.0]:
				var c3: Vector3 = m.flight.center(b.index, m.view.t + dt)
				if p.distance_to(Vector2(c3.x, c3.z)) < maxf(b.soi, 30.0) * 2.0 + 20.0:
					clear = false
		if clear:
			return p
	return Vector2(cos(a0), sin(a0)) * r


## The box the words `s` were placed in last frame, or an empty one.
func _said_box(ov, s: String) -> Rect2:
	for k in (ov.label_says as Array).size():
		if String(ov.label_says[k]) == s:
			return ov.label_rects[k]
	return Rect2()


static func _box_on_disc(box: Rect2, c: Vector2, r: float) -> bool:
	var near := Vector2(clampf(c.x, box.position.x, box.end.x), clampf(c.y, box.position.y, box.end.y))
	return near.distance_to(c) < r


## The words placed last frame (`SystemOverlay.label_rects`) across a sun's
## disc, counted, each added to `out` as "<where>: <words> across <star>".
static func _words_on_suns(ov, L: SystemLayout, where: String, out: Array[String]) -> int:
	var k := 0
	for q in (ov.label_rects as Array).size():
		var box: Rect2 = ov.label_rects[q]
		for s: int in L.stars():
			if _box_on_disc(box, ov.star_scr(s), ov.star_disc(s)):
				k += 1
				out.append("%s: %s across %s" % [where, ov.label_says[q], ov.star_name_of(s)])
	return k


## The words the overlay held back last frame to keep them off a sun
## (`SystemOverlay.label_held`; none on a tree without it, so the sheet still
## judges one).
static func _held(ov) -> Array:
	var got = ov.get(&"label_held")
	return got if got is Array else []


## THE BEACON THE BOX `box` IS OVER, of every event's beacon drawn last frame
## (`SystemOverlay.beacons_at`, each glyph 5 cells of 2 px round its point: a
## 10 px square from 4 px up and left of it), or Vector2.INF for none.
static func _on_beacon(ov, box: Rect2) -> Vector2:
	for e: Array in ov.beacons_at:
		var at: Vector2 = e[0]
		if box.intersects(Rect2(at.round() + Vector2(-4, -4), Vector2(10, 10))):
			return at.round()
	return Vector2.INF


## THE CORNER TICKS OF THE RETICLE round `at` (`SystemOverlay._reticle`: two
## 3 px ticks meeting `reach` out at each corner), each the 3 px square they
## stand in.
static func _tick_boxes(at: Vector2, reach: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var kp: Vector2 = (at + corner * reach).round()
		out.append(Rect2(kp - Vector2(0.0 if corner.x > 0 else 2.0, 0.0 if corner.y > 0 else 2.0), Vector2(3, 3)))
	return out


## THE SHIP'S OWN WORDS OFF THE BEACONS: `full` (IN ORBIT · <world>, CLOSE ORBIT
## · <star>) or the words before its " · ", as placed last frame, against every
## event's beacon drawn that frame (`_on_beacon`). Counted in `st`: placed
## (`bc_words`); left by a beacon where no spot cleared the suns and the
## beacons both (`bc_fallback`, `SystemOverlay.label_on_beacon`; none on a tree
## without it); over a beacon all the same (`bc_crossed`), each added to `out`.
## AND WHERE THE OVERLAY STEPPED THEM clear of the beacons (`bc_stepped`,
## `SystemOverlay.ship_words` clear &"all" or &"marks"): off the corner ticks of
## the reticle round `place`, the place they name (`bc_ticks` where not), and
## over none of the words they hid (`SystemOverlay.label_under`; `bc_hid` where
## they are) but where the overlay says no spot cleared those as well (&"marks",
## `bc_marks`). Words where they first stood may cross the ticks under the ring,
## as with one sun; stepped, the ticks once moved them 20 px and they hid a
## selected place's name a step less far would have shown (the review of
## 19fd37e5, Nov 1).
static func _ship_words_off_beacons(ov, full: String, place: int, where: String, st: Dictionary, out: Array[String]) -> void:
	var short := full.get_slice(" · ", 0)
	var fell = ov.get(&"label_on_beacon")
	var how = ov.get(&"ship_words")
	var hid = ov.get(&"label_under")
	for q in (ov.label_says as Array).size():
		var s: String = ov.label_says[q]
		if s != full and s != short:
			continue
		st.bc_words += 1
		if fell is Array and (fell as Array).has(s):
			st.bc_fallback += 1
			continue
		var box: Rect2 = ov.label_rects[q]
		var bat := _on_beacon(ov, box)
		if bat != Vector2.INF:
			st.bc_crossed += 1
			out.append("%s: %s over the beacon at %s" % [where, s, bat])
		if not (how is Dictionary) or String((how as Dictionary).get("says", "")) != s:
			continue
		var clear := StringName((how as Dictionary).get("clear", &""))
		if clear != &"all" and clear != &"marks":
			continue
		st.bc_stepped += 1
		if SystemLayout.is_place(place) and not ov._is_belt(place):
			for r: Rect2 in _tick_boxes(ov._place_scr(place), ov._reach(place)):
				if box.intersects(r):
					st.bc_ticks += 1
					out.append("%s: %s, stepped, on the reticle's tick at %s" % [where, s, r.position])
					break
		if hid is Array:
			for e: Array in hid:
				if box.intersects(e[1]):
					if clear == &"marks":
						st.bc_marks += 1
					else:
						st.bc_hid += 1
						out.append("%s: %s, stepped, hid %s" % [where, s, e[0]])
					break


## WHETHER WORDS `s` WERE HELD UNDER THE SHIP'S OWN WORDS last frame (`full`, or
## the words before its " · "): where they would have stood
## (`SystemOverlay.label_under`) across where those stand. False on a tree
## without the record.
static func _under_ship_words(ov, s: String, full: String) -> bool:
	var hid = ov.get(&"label_under")
	if not (hid is Array):
		return false
	var box := Rect2()
	for q in (ov.label_says as Array).size():
		if String(ov.label_says[q]) == full or String(ov.label_says[q]) == full.get_slice(" · ", 0):
			box = ov.label_rects[q]
	if box.size.x <= 0.0:
		return false
	for e: Array in hid:
		if String(e[0]) == s and box.intersects(e[1]):
			return true
	return false


## WORDS `s` AS PLACED LAST FRAME OVER A BEACON (`_on_beacon`), counted in
## `st[key]`.
func _said_on_beacon(ov, s: String, st: Dictionary, key: String) -> void:
	var box := _said_box(ov, s)
	if box.size.x > 0.0 and _on_beacon(ov, box) != Vector2.INF:
		st[key] = int(st[key]) + 1


## THE CURL DRAWN FOR A CAPTURE INTO STAR B'S CLOSE ORBIT IS THE ONE FLOWN: the
## overlay's (`SystemOverlay.capture_ins`) against `ShipFlight.start_rail`'s own
## insertion, for captures just inside B's ring from all round it, coming in
## and going round both ways. Drawn against star A's keep-out it was up to 58
## px off the curl flown (the seams review, Oct 31).
func _capture_curl_b(n: MapGen.MapNode) -> void:
	var m := Router.current as SystemMapScreen
	if m == null:
		m = await _map()
	if m == null:
		h._fail("no map for the curl")
		return
	var L: SystemLayout = m.view.layout
	var B := SystemLayout.STAR_B
	var worst := 0.0
	var worst_a := 0.0
	var cases := 0
	for k in 12:
		var a := float(k) / 12.0 * TAU
		var rh := Vector2(cos(a), sin(a))
		for sense: float in [1.0, -1.0]:
			var rel := rh * (L.star_ring_of(B) - 0.6)
			var rv := rh.orthogonal() * 28.0 * sense - rh * 12.0
			var fl = FlightS.new()
			fl.setup(L, Vector2(L.edge, -210.0), m.view.t)
			fl.start_rail(B, rel, rv, m.view.t)
			if not fl.rail.has("ins"):
				continue
			var drawn: Dictionary = m.overlay.capture_ins(B, rel, rv)
			var rt: float = m.flight.orbit_r(B)
			var dir := 1.0 if rel.x * rv.y - rel.y * rv.x >= 0.0 else -1.0
			var as_a: Dictionary = m.flight.insert_plan(rel, rv, rt, dir * m.flight.STAR_RAIL_V / rt, null)
			cases += 1
			for j in 21:
				var u := float(j) / 20.0
				var q: Vector2 = fl._ins_at(fl.rail.ins, u, 0)
				worst = maxf(worst, q.distance_to(m.flight._ins_at(drawn, u, 0)))
				worst_a = maxf(worst_a, q.distance_to(m.flight._ins_at(as_a, u, 0)))
	h._ok("a capture into star B's close orbit is drawn as it is flown: %d captures, worst %.3f px apart (cleared against star A's keep-out, as it was drawn, %.1f px)" % [cases, worst, worst_a], cases > 0 and worst < 0.01)
	_saw("captures at star B", cases)


## THE MAP LEFT ON A FLIGHT'S COAST (Tab, the HUD's tabs, SAVE & EXIT): the
## ship is where it was going, in orbit there -- LOCAL told so (`Run.site_here`)
## and the flight counted (`flown_to`), the map putting it back on that orbit.
## It put the ship back at the system's edge with the flight gone, and ruling
## 20's flights, about 24 s, made that several times as likely (the reviews,
## Oct 31). On the way, the map_fly hint ("Click a world twice to fly there")
## keeps quiet: a click does nothing then.
func _mid_flight_tab(n: MapGen.MapNode, what: String) -> void:
	var m := await _map()
	if m == null:
		h._fail("%s: no map for the flight" % what)
		return
	var L: SystemLayout = m.view.layout
	# (from star A's close orbit to the world furthest from it: a long coast)
	var from := -1
	var to := -9
	var far := 0.0
	for b in L.bodies:
		var c3: Vector3 = m.flight.center(b.index, m.view.t)
		if b.world != &"" and Vector2(c3.x, c3.z).length() > far:
			far = Vector2(c3.x, c3.z).length()
			to = b.index
	m.flight.place_at(from, m.view.t)
	for i in 120:
		if m.flight.can_fly():
			break
		await get_tree().process_frame
	m.fly_to_body(to)
	var coast := false
	var quiet := true
	for i in 1200:
		await get_tree().process_frame
		if m.flight.mode == &"fly":
			if not Hints._map_fly_probe(m, Rect2()).is_empty():
				quiet = false
			if m.view.t - float(m.flight.fly_t0) > 2.0:
				coast = true
				break
	if not h._ok("%s: on its way to %s, 2 s into the flight (mode %s)" % [what, L.bodies[to].name, m.flight.mode], coast):
		return
	h._ok("%s: the map_fly hint keeps quiet on the way" % what, quiet)
	var n0 := SystemMapScreen.flights
	Router.show_local()
	await _idle()
	await _frames(4)
	var ft: Dictionary = SystemMapScreen.flown_to.get(n.index, {})
	h._ok("%s: left on the way, the ship is at %s as LOCAL is told (site %d), the flight counted (%d, flown to %s)" % [
		what, L.bodies[to].name, Run.site_here(), SystemMapScreen.flights - n0, ft],
		Run.site_here() == to and SystemMapScreen.flights == n0 + 1 and int(ft.get("at", -9)) == to)
	m = await _map()
	h._ok("%s: and the map puts it on that orbit (%d, %s)" % [what, m.flight.reached() if m != null else -99, m.flight.mode if m != null else &""],
		m != null and m.flight.reached() == to and m.flight.mode == &"rail")
	_saw("flights left on the way")


## THE MAP DRAWN AGAIN ROUND A FLIGHT, as Settings' style and GRAPHICS rows do
## it (`Sig.render_style_changed`, `SystemMapScreen._on_style`): the flight's
## errand goes on with the new ship (`ShipFlight.hand_over`, `_carry_on`). It was
## lost: a GO cut short this way left the ship at its target with the event
## never opened, and `_taking` true, so the map took no click, hover, zoom, drag,
## WASD or FLY HERE until it was left (the recheck's probe, Oct 31, both a twin
## and one sun; main has the same code, ruling 20's ~24 s flights made it likely).
func _restyle_mid_flight(n: MapGen.MapNode, what: String) -> void:
	var m := await _map()
	if m == null:
		h._fail("%s: no map to draw again" % what)
		return
	var L: SystemLayout = m.view.layout
	# (from the world nearest the middle to the one furthest from it: a coast)
	var a := -9
	var b := -9
	var near := INF
	var far := 0.0
	for bd in L.bodies:
		if bd.world == &"":
			continue
		var c3: Vector3 = m.flight.center(bd.index, m.view.t)
		var d := Vector2(c3.x, c3.z).length()
		if d < near:
			near = d
			a = bd.index
		if d > far:
			far = d
			b = bd.index
	if not h._ok("%s: two worlds to fly between when the map is drawn again (%d, %d)" % [what, a, b], a >= 0 and b >= 0 and a != b):
		return
	var ran := [0]
	var errand := func() -> void: ran[0] += 1

	# A GO ON ITS COAST: in orbit there, its errand run once, the map open
	await _sit(m, a)
	var n0 := SystemMapScreen.flights
	m._go_then(b, errand)
	var coasting: bool = await _coast(m, 2.0)
	if not h._ok("%s: a GO is on its coast to %s, 2 s in (mode %s)" % [what, L.bodies[b].name, m.flight.mode], coasting):
		return
	m = await _restyle(m)
	h._ok("%s: drawn again on its coast, the GO is in orbit of %s (%d, %s), its errand run once (%d), the map open (_taking %s), the flight counted once (%d)" % [
		what, L.bodies[b].name, m.flight.reached(), m.flight.mode, ran[0], m._taking, SystemMapScreen.flights - n0],
		m.flight.reached() == b and ran[0] == 1 and not m._taking and SystemMapScreen.flights == n0 + 1)
	await _frames(30)
	m.fly_to_body(a)
	await _frames(2)
	h._ok("%s: the errand not run again (%d), and FLY HERE flies (heading to %d)" % [what, ran[0], m.flight.heading_to()],
		ran[0] == 1 and m.flight.heading_to() == a)

	# A GO STILL BEING PLANNED (or riding round to leave): put back where it was
	# leaving, it flies on, the map shut for it, and its errand runs on arrival
	await _sit(m, a)
	ran[0] = 0
	n0 = SystemMapScreen.flights
	m._go_then(b, errand)
	var before := "%s, planning %s" % [m.flight.mode, m.flight.planning(&"fly")]
	if not h._ok("%s: a GO asked for, not yet flying (%s, heading to %d)" % [what, before, m.flight.heading_to()],
			m.flight.heading_to() == b and m.flight.mode != &"fly" and m.flight.reached() == -9):
		return
	m = await _restyle(m)
	var on: bool = m.flight.heading_to() == b and m._taking and ran[0] == 0
	var land := -1.0
	for i in 90 * 60:
		await get_tree().process_frame
		if ran[0] > 0:
			land = float(i) / 60.0
			break
	await _frames(30)
	h._ok("%s: drawn again before it left, the GO flies on to %s (heading there, map shut: %s) and its errand runs on arrival, once (%d, %.1f s on; in orbit %d, _taking %s, counted %d)" % [
		what, L.bodies[b].name, on, ran[0], land, m.flight.reached(), m._taking, SystemMapScreen.flights - n0],
		on and ran[0] == 1 and m.flight.reached() == b and not m._taking and SystemMapScreen.flights == n0 + 1)

	# A FLY HERE ON ITS COAST: in orbit there, the place opened
	await _sit(m, a)
	m.fly_to_body(b)
	coasting = await _coast(m, 2.0)
	if not h._ok("%s: FLY HERE is on its coast to %s, 2 s in (mode %s)" % [what, L.bodies[b].name, m.flight.mode], coasting):
		return
	m = await _restyle(m)
	await _frames(4)
	h._ok("%s: drawn again on its coast, FLY HERE is in orbit of %s (%d) with it opened (selected %d, panel %s %d)" % [
		what, L.bodies[b].name, m.flight.reached(), m.overlay.selected, m.panel.mode, m.panel.filter],
		m.flight.reached() == b and m.overlay.selected == b and m.panel.mode == &"list" and m.panel.filter == b)

	# A FLIGHT LET GO OF (W while it is planned or rides round to leave) is not
	# flown again by the new ship
	await _sit(m, a)
	m.fly_to_body(b)
	m.harness_keys = true
	m._wasd.w = true
	await _frames(1)
	m._wasd.w = false
	await _frames(1)
	m.harness_keys = false
	if m.flight.heading_to() != -9:
		print("  --   %s: the flight left before W could let go of it (mode %s): that case not seen" % [what, m.flight.mode])
	else:
		m = await _restyle(m)
		# (coasting off the ring it may be caught by one close by, as any coast
		# is: that is not a flight; one to the far world, or planned, is)
		var flew := false
		for i in 120:
			await get_tree().process_frame
			if m.flight.mode == &"fly" or m.flight.planning(&"fly") or m.flight.heading_to() == b:
				flew = true
				break
		h._ok("%s: a flight let go of with W is not flown again when the map is drawn again (mode %s, heading to %d, _taking %s)" % [
			what, m.flight.mode, m.flight.heading_to(), m._taking], not flew and not m._taking)
	# (left in orbit, for the parts after)
	await _sit(m, a)
	_saw("flights the map was drawn again round")


## A GO LEAVES THE VIEW OPEN (kept finding [11], Nov 1: the whole map was shut
## for the flight, about 27 s on map time), through the window's own input
## (`push_input`, so the map's frame takes it as a hand's): while it flies the
## pointer hovers and its tip shows, offering no click; the wheel zooms; a drag
## pans; a right-click is the view's. A click, a double click, FLY HERE and WASD
## are refused, so the GO's errand is the one that runs, once, on arrival, and
## after it a click selects again.
func _go_view_open(n: MapGen.MapNode, what: String) -> void:
	var m := await _map()
	if m == null:
		h._fail("%s: no map for a GO" % what)
		return
	var L: SystemLayout = m.view.layout
	# (from the world nearest the middle to the one furthest from it, and a
	# third world to point at and click on)
	var a := -9
	var b := -9
	var near := INF
	var far := 0.0
	for bd in L.bodies:
		if bd.world == &"":
			continue
		var c3: Vector3 = m.flight.center(bd.index, m.view.t)
		var d := Vector2(c3.x, c3.z).length()
		if d < near:
			near = d
			a = bd.index
		if d > far:
			far = d
			b = bd.index
	if not h._ok("%s: two worlds a GO flies between (%d, %d)" % [what, a, b], a >= 0 and b >= 0 and a != b):
		return
	var ran := [0]
	var errand := func() -> void: ran[0] += 1
	await _sit(m, a)
	var n0 := SystemMapScreen.flights
	m._go_then(b, errand)
	var coasting: bool = await _coast(m, 1.0)
	if not h._ok("%s: the GO is on its coast to %s (mode %s)" % [what, L.bodies[b].name, m.flight.mode], coasting):
		return
	var sel0: int = m.overlay.selected
	var page0 := "%s %d %d" % [m.panel.mode, m.panel.filter, m.panel.open_opt]
	var c := _pointable(m, [a, b])
	if not h._ok("%s: a place on screen to point at mid-GO (%d)" % [what, c], SystemLayout.is_place(c)):
		return
	_pointer_on(m)
	_took = 0
	_sent = 0
	# THE POINTER HOVERS, and the tip offers no click
	var q: Vector2 = _place_q(m, c)
	var want: Dictionary = m.overlay.hit(q)
	_push_motion(_win_at(m, q))
	var hv: Dictionary = m.overlay.hover
	var tl: Array = m.overlay.tip_lines(hv)[0] if not hv.is_empty() else []
	var offers := tl.any(func(l: Array) -> bool: return String(l[0]).begins_with("CLICK"))
	h._ok("%s: mid-GO the pointer hovers %s %d (want %s %d), its tip up (%d lines) and offering no click (%s)" % [what, hv.get("kind", &""), int(hv.get("body", -99)),
		want.get("kind", &""), int(want.get("body", -99)), tl.size(), " / ".join(PackedStringArray(tl.map(func(l: Array) -> String: return String(l[0]))))],
		not hv.is_empty() and hv.get("kind") == want.get("kind") and int(hv.get("body", -99)) == int(want.get("body", -98)) and tl.size() >= 2 and not offers)
	var qb: Vector2 = m.view.at[b]
	if Rect2(Vector2.ZERO, m._frame.size).has_point(m._box.position + qb) and m.overlay.hit(qb).get("body", -99) == b:
		_push_motion(_win_at(m, qb))
		var tb: Array = m.overlay.tip_lines(m.overlay.hover)[0] if not m.overlay.hover.is_empty() else [["(no hover)", Color.WHITE]]
		h._ok("%s: and on where it is going, ON YOUR WAY (%s)" % [what, tb[tb.size() - 1][0]], String(tb[tb.size() - 1][0]) == "ON YOUR WAY")
	# THE WHEEL ZOOMS
	var z0: float = m._zoom_to
	q = _place_q(m, c)
	_push_button(_win_at(m, q), MOUSE_BUTTON_WHEEL_UP, true)
	_push_button(_win_at(m, q), MOUSE_BUTTON_WHEEL_UP, false)
	var z1: float = m._zoom_to
	for i in 120:
		await get_tree().process_frame
		if absf(m.view.zoom - m._zoom_to) < 0.0005:
			break
	h._ok("%s: mid-GO the wheel zooms (%.3f to %.3f, the view at %.3f)" % [what, z0, z1, m.view.zoom], z1 > z0 * 1.01 and absf(m.view.zoom - z1) < 0.002)
	# A DRAG PANS (and lets go of LOCATION, as any drag does), and is no click
	var mid: Vector2 = m._frame.size * 0.5 - m._box.position
	var pan0: Vector2 = m.view.pan
	_push_motion(_win_at(m, mid))
	_push_button(_win_at(m, mid), MOUSE_BUTTON_LEFT, true)
	for k in [10.0, 25.0, 40.0]:
		_push_motion(_win_at(m, mid + Vector2(k, 6.0)), Vector2(15.0, 2.0), true)
	_push_button(_win_at(m, mid + Vector2(40.0, 6.0)), MOUSE_BUTTON_LEFT, false)
	var moved: Vector2 = m.view.pan - pan0
	# (as far as the map lets a view go, `_clamp_pan`)
	var zv: float = m.view.zoom
	var reach := Vector2((L.edge + 40.0) * zv, ((L.edge + 40.0) * float(m.view.TILT) + 40.0) * zv)
	var lim := (reach - m._frame.size * 0.25).max(Vector2.ZERO)
	var want_mv: Vector2 = (pan0 + Vector2(40.0, 6.0)).clamp(-lim, lim) - pan0
	h._ok("%s: mid-GO a drag pans the view (%s px for a 40, 6 px drag, %s as far as it may go), selecting nothing (%d)" % [what, moved, want_mv, m.overlay.selected],
		moved.length() > 1.0 and moved.distance_to(want_mv) < 0.5 and m.overlay.selected == sel0)
	await _frames(2)
	# A CLICK AND A DOUBLE CLICK ON ANOTHER WORLD, A RIGHT-CLICK, FLY HERE AND
	# WASD: none selects, opens or flies; the GO goes on
	q = _place_q(m, c)
	if Rect2(Vector2.ZERO, m._frame.size).has_point(m._box.position + q):
		_push_motion(_win_at(m, q))
		_push_button(_win_at(m, q), MOUSE_BUTTON_LEFT, true)
		_push_button(_win_at(m, q), MOUSE_BUTTON_LEFT, false)
		_push_button(_win_at(m, q), MOUSE_BUTTON_LEFT, true, true)
		_push_button(_win_at(m, q), MOUSE_BUTTON_LEFT, false)
	_push_button(_win_at(m, mid), MOUSE_BUTTON_RIGHT, true)
	_push_button(_win_at(m, mid), MOUSE_BUTTON_RIGHT, false)
	m.fly_to_body(c)
	m.harness_keys = true
	m._wasd.w = true
	await _frames(10)
	m._wasd.w = false
	m.harness_keys = false
	var page1 := "%s %d %d" % [m.panel.mode, m.panel.filter, m.panel.open_opt]
	h._ok("%s: mid-GO a click, a double click, a right-click (it only moves the view), FLY HERE and W select, open and fly nothing (selected %d, was %d; page %s, was %s; heading to %d, mode %s, _taking %s)" % [
		what, m.overlay.selected, sel0, page1, page0, m.flight.heading_to(), m.flight.mode, m._taking],
		m.overlay.selected == sel0 and page1 == page0 and m.flight.heading_to() == b and m._taking and ran[0] == 0)
	# ON ARRIVAL ITS ERRAND RUNS, ONCE, AND THE MAP TAKES CLICKS AGAIN
	var land := -1.0
	for i in 90 * 60:
		await get_tree().process_frame
		if ran[0] > 0:
			land = float(i) / 60.0
			break
	await _frames(30)
	h._ok("%s: the GO lands in orbit of %s (%d) with its errand run once (%d, %.1f s on), the map open (_taking %s, the tip's clicks %s), counted once (%d)" % [
		what, L.bodies[b].name, m.flight.reached(), ran[0], land, m._taking, "held" if m.overlay.clicks_held else "offered", SystemMapScreen.flights - n0],
		m.flight.reached() == b and ran[0] == 1 and not m._taking and not m.overlay.clicks_held and SystemMapScreen.flights == n0 + 1)
	c = _pointable(m, [b])
	if SystemLayout.is_place(c):
		q = _place_q(m, c)
		var hit_c: Dictionary = m.overlay.hit(q)
		_push_motion(_win_at(m, q))
		_push_button(_win_at(m, q), MOUSE_BUTTON_LEFT, true)
		_push_button(_win_at(m, q), MOUSE_BUTTON_LEFT, false)
		await _frames(2)
		h._ok("%s: after it, a click selects again (%d, want %d)" % [what, m.overlay.selected, int(hit_c.get("body", -99))],
			m.overlay.selected == int(hit_c.get("body", -98)))
	h._ok("%s: every pointer event reached the map's frame through the game's viewport (%d of %d)" % [what, _took, _sent], _sent > 15 and _took == _sent)
	_pointer_off(m)
	await _sit(m, a)
	_saw("GOs with the view open")


## Where place p is drawn on the map: a body's point, a star's sun.
func _place_q(m: SystemMapScreen, p: int) -> Vector2:
	return m.overlay.star_scr(p) if SystemLayout.is_star(p) else m.view.at[p]


## A place (not one of `skip`: a world, a station, hulk or contact, or either
## star) drawn on the map's frame, clear of its edge and the LOCATION button,
## whose point hits it; or -9.
func _pointable(m: SystemMapScreen, skip: Array) -> int:
	var fr := Rect2(Vector2(24.0, 24.0), m._frame.size - Vector2(48.0, 48.0))
	var ids: Array[int] = []
	for bd in m.view.layout.bodies:
		if bd.world != &"" or bd.kind in [&"station", &"derelict", &"contact"]:
			ids.append(bd.index)
	ids.append_array(m.view.layout.stars())
	for p: int in ids:
		if skip.has(p):
			continue
		var q := _place_q(m, p)
		if fr.has_point(m._box.position + q) and int(m.overlay.hit(q).get("body", -99)) == p \
				and not m._loc_btn.get_global_rect().grow(6.0).has_point(_win_at(m, q)):
			return p
	return -9


## The map's point q (its picture's pixels, as `SystemOverlay.hit` takes them)
## in the game's own 960x540 viewport, as `push_input` takes it there.
func _win_at(m: SystemMapScreen, q: Vector2) -> Vector2:
	return m._frame.global_position + m._box.position + q


## THE POINTER, AS A HAND MOVES IT: each event pushed into the game's viewport
## (`GameShell.input_target`; the game is in the shell's SubViewport), which is
## told the pointer is in it (headless the window never has it, and a motion
## then reaches no control), and counted where the map's frame takes it: every
## one must reach it, or the test measured something lying on the map.
var _took := 0
var _sent := 0


func _pointer_on(m: SystemMapScreen) -> void:
	GameShell.input_target(get_tree()).notification(Node.NOTIFICATION_VP_MOUSE_ENTER)
	if not m._frame.gui_input.is_connected(_frame_took):
		m._frame.gui_input.connect(_frame_took)


func _pointer_off(m: SystemMapScreen) -> void:
	if m != null and is_instance_valid(m) and m._frame.gui_input.is_connected(_frame_took):
		m._frame.gui_input.disconnect(_frame_took)
	GameShell.input_target(get_tree()).notification(Node.NOTIFICATION_VP_MOUSE_EXIT)


func _frame_took(_e: InputEvent) -> void:
	_took += 1


func _send(ev: InputEventMouse) -> void:
	_sent += 1
	GameShell.input_target(get_tree()).push_input(ev, true)


func _push_motion(at: Vector2, rel := Vector2.ZERO, held := false) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	mm.relative = rel
	if held:
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	_send(mm)


func _push_button(at: Vector2, idx: MouseButton, down: bool, dbl := false) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = idx
	ev.pressed = down
	ev.double_click = dbl
	ev.position = at
	ev.global_position = at
	if down and idx == MOUSE_BUTTON_LEFT:
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	_send(ev)


## In orbit of world i, out of any flight, nothing selected (so no preview is
## of the next target), free to fly.
func _sit(m: SystemMapScreen, i: int) -> void:
	m.panel_back()
	m.flight.place_at(i, m.view.t)
	for k in 120:
		await get_tree().process_frame
		if m.flight.can_fly() and m.flight.reached() == i:
			break
	await _frames(10)


## Until the flight has coasted `secs` (true), or it never does.
func _coast(m: SystemMapScreen, secs: float) -> bool:
	for i in 1800:
		await get_tree().process_frame
		if m.flight.mode == &"fly" and m.view.t - float(m.flight.fly_t0) > secs:
			return true
	return false


## THE MAP DRAWN AGAIN as Settings does it (`Sig.render_style_changed`); back
## once its new ship is in (the errand handed over in the same frame).
func _restyle(m: SystemMapScreen) -> SystemMapScreen:
	var was = m.flight
	Sig.render_style_changed.emit()
	for i in 600:
		await get_tree().process_frame
		if m.flight != null and m.flight != was:
			break
	if m.flight == null or m.flight == was:
		h._fail("the map was not drawn again (no new ship)")
	return m


## HOLDING ALONGSIDE TO LEAVE (`FlightSolve`'s KEEP_HOLD, and while the flight
## is planned): the status line says LEAVING · TO <place> and the words by the
## ship LEAVING · <here>, as a ring's ride round to leave says LEAVING ORBIT. It
## said ALONGSIDE, and YOU by the ship, with the flight already drawn (the
## seams and seen reviews). In the first system of the run with a station,
## belt, hulk or contact.
func _alongside_hold() -> void:
	var was_at := Run.at
	var keep_n: MapGen.MapNode = null
	var kb := -1
	var wb := -1
	for raw in Run.map:
		var c: MapGen.MapNode = raw
		if c.type != MapGen.NodeType.SYSTEM or c.region == MapGen.Region.FAUNA:
			continue
		var L := SystemLayout.of(c)
		var k0 := -1
		var w0 := -1
		for b in L.bodies:
			if k0 < 0 and (b.kind == &"station" or b.kind == &"belt" or b.kind == &"derelict" or b.kind == &"contact"):
				k0 = b.index
			if w0 < 0 and b.world != &"":
				w0 = b.index
		if k0 >= 0 and w0 >= 0:
			keep_n = c
			kb = k0
			wb = w0
			break
	if not h._ok("a system with a place to sit alongside", keep_n != null):
		return
	Run.at = keep_n.index
	keep_n.visited = true
	SystemMapScreen._parked[keep_n.index] = {"at": kb, "mode": &"keep"}
	var m := await _map()
	if m == null or not h._ok("alongside %s (%d)" % [m.view.layout.bodies[kb].name, m.flight.reached()], m.flight.reached() == kb):
		Run.at = was_at
		return
	var ov = m.overlay
	var here: String = m.view.layout.bodies[kb].name
	var there: String = m.view.layout.bodies[wb].name
	m.fly_to_body(wb)
	var said := {}
	var words := {}
	var held := 0
	for i in 600:
		await get_tree().process_frame
		if m.flight.mode == &"keep" and m.flight.keep.has("hold"):
			held += 1
			said[String(ov.ship_status()[0])] = true
			for w: String in ov.label_says:
				if w.begins_with("LEAVING") or w == "YOU" or w.begins_with("ALONGSIDE"):
					words[w] = true
		elif m.flight.mode == &"fly":
			break
	h._ok("holding alongside to leave (%d frames), the status line says LEAVING · TO %s (%s) and the ship LEAVING · %s (%s)" % [
		held, there, ", ".join(PackedStringArray(said.keys())), here, ", ".join(PackedStringArray(words.keys()))],
		held > 0 and said.keys() == ["LEAVING · TO " + there] and words.has("LEAVING · " + here) and not words.has("YOU"))
	Run.at = was_at
	_saw("holds alongside")


## IT QUITS WITH A FLIGHT PLAN STILL BEING MADE on a worker (a preview asked
## for this frame): the quit waits for it (`ShipFlight.drain`, Router). Not
## waited for, its task crashed the quit, signal 11, exit 134 (the scroll
## check, 3 of 3; the saves review's QuitLens, Oct 31).
## THE ZOOM LADDER HANDS THE PAIR OVER WHERE IT STANDS (ruling 23; the review of
## the plan, "the zoom-ladder handovers"), the moves animated as in play
## (`Router.animate_in_harness`, the ladder's clock 1/30 s a frame), on a wide
## pair's map opened a quarter of the way round its lap:
##   - down to LOCAL, the map's clock kept at the click holds through the move
##     (`SystemMapScreen.clock_held`), so the clock LOCAL is handed
##     (`Run.map_t`) is the one the map last drew;
##   - back up, the map built ahead (`ZoomLadder.prebuilt`) waits at that clock
##     and holds it through the move, then runs on once it lands;
##   - out to the chart by 1A (behind the calm switch, as LadderTest's every
##     design), the move anchors on star A where it is now (`ladder_anchor`,
##     the sun its hole shows, `ladder_sun`), not on the plane's origin where
##     star A stood at t 0, and the map's clock holds through it too.
## Running on through a move, the suns stood a frame's worth of turn or a whole
## pre-roll's from where the other picture had them, and a map built ahead and
## dropped wrote its moved clock back.
func _ladder_holds_the_pair() -> void:
	var m0 := Router.current as SystemMapScreen
	if m0 == null or m0.view.layout == null or not m0.view.layout.twin or m0.view.layout.close:
		h._fail("no wide pair's map for the ladder")
		return
	var n: MapGen.MapNode = m0.view.node
	var L0: SystemLayout = m0.view.layout
	var lap: float = TAU / L0.pair_n if L0.pair_n > 0.0 else 0.0
	Router.show_local()
	await _idle()
	await _frames(2)
	Run.map_clock[n.index] = lap * 0.25 + 3.0
	var m := await _map()
	if not h._ok("the map up again at a kept clock a quarter of the pair's lap round (%.1f)" % (m.view.t if m != null else -1.0), m != null and m.view.node == n):
		return
	var was_force := ZoomLadder.force
	Router.animate_in_harness = true
	ZoomLadder.fixed_dt = 1.0 / 30.0
	ZoomLadder.force = 1
	# DOWN TO LOCAL
	await _frames(4)
	var t_click: float = m.view.t
	Router.show_local()
	var moved := 0.0
	var frames := 0
	for i in 600:
		await get_tree().process_frame
		frames += 1
		if is_instance_valid(m) and m.view != null:
			moved = maxf(moved, absf(float(m.view.t) - t_click))
		if not ZoomLadder.busy():
			break
	h._ok("down to LOCAL (%d frames): the map's clock held at the click (%.3f, moved %.4f s), and LOCAL handed it (%.3f)" % [
		frames, t_click, moved, Run.map_t(n.index)], Router.current is SectorScreen and moved == 0.0 and Run.map_t(n.index) == t_click)
	# BACK UP TO THE MAP, built ahead at that clock
	var t_kept := Run.map_t(n.index)
	await _frames(10)
	Router.show_system()
	var pm: Control = ZoomLadder.prebuilt_screen()
	var off := 0.0
	var seen := 0
	for i in 600:
		await get_tree().process_frame
		var mm = pm if pm != null and is_instance_valid(pm) else Router.current
		if mm is SystemMapScreen and (mm as SystemMapScreen).view.layout != null and ZoomLadder.busy():
			seen += 1
			off = maxf(off, absf(float((mm as SystemMapScreen).view.t) - t_kept))
		if not ZoomLadder.busy():
			break
	var up := Router.current as SystemMapScreen
	await _frames(20)
	h._ok("up to the map: built ahead (%s) at the clock LOCAL held (%.3f), held through the move (%d frames, %.4f s off), running on once it lands (%.3f)" % [
		pm != null, t_kept, seen, off, up.view.t if up != null else -1.0],
		up != null and pm == up and seen > 0 and off == 0.0 and float(up.view.t) > t_kept)
	# OUT TO THE CHART, 1A: anchored on star A where it is
	if up != null:
		ZoomLadder.calm_force = 0
		ZoomLadder.force_design = {1: "A"}
		var star_a: Vector2 = up._frame.global_position + up._box.position + (up.view.star_exact(-1) as Vector2)
		var anchor: Vector2 = up.ladder_anchor(ZoomLadder.CHART, 1, "A")
		var sun: Dictionary = up.ladder_sun()
		var origin: Vector2 = up._ladder_origin()
		h._ok("out to the chart (1A), the pair %.0f deg round: the move anchors on star A where it is (%s; star A at %s, the plane's origin where it stood at t 0 %s), the sun its hole shows there too (%s)" % [
			rad_to_deg(L0.pair_n * float(up.view.t)), anchor, star_a, origin, sun.get("c", Vector2.INF)],
			anchor.distance_to(star_a) < 0.5 and (sun.get("c", Vector2.INF) as Vector2).distance_to(star_a) < 0.5 and (origin.distance_to(star_a) > 4.0 or lap == 0.0))
		var t_out: float = up.view.t
		Router.show_starchart()
		var out_moved := 0.0
		# (the map's camera moves out first, so star A as it stood each frame, the
		# frame the old picture is held and the one before)
		var a_old := Vector2.INF
		var near_a := INF
		var near_o := INF
		var was_a: Array = []
		for i in 600:
			var star_now: Vector2 = up._ladder_star() if is_instance_valid(up) and up.view != null else Vector2.INF
			var origin_now: Vector2 = up._ladder_origin() if is_instance_valid(up) and up.view != null else Vector2.INF
			await get_tree().process_frame
			if is_instance_valid(up) and up.view != null:
				out_moved = maxf(out_moved, absf(float(up.view.t) - t_out))
			was_a.append([star_now, origin_now])
			if ZoomLadder.busy() and a_old == Vector2.INF and ZoomLadder.active._a_old != Vector2.ZERO:
				a_old = ZoomLadder.active._a_old
				for e: Array in was_a.slice(maxi(0, was_a.size() - 2)):
					near_a = minf(near_a, a_old.distance_to(e[0]))
					near_o = minf(near_o, a_old.distance_to(e[1]))
			if not ZoomLadder.busy():
				break
		h._ok("and the move holds the map's clock (%.4f s moved), the old picture held anchored on star A (%s: %.2f px off star A, %.1f off the plane's origin)" % [out_moved, a_old, near_a, near_o],
			Router.current is StarchartScreen and out_moved == 0.0 and a_old != Vector2.INF and near_a < 1.0 and (near_o > 2.0 or lap == 0.0))
		ZoomLadder.force_design = {}
		ZoomLadder.calm_force = -1
	ZoomLadder.force = was_force
	ZoomLadder.fixed_dt = -1.0
	Router.animate_in_harness = false
	_saw("ladder moves with the pair turned", 3)


func _end_planning() -> void:
	var m := await _map()
	if m == null:
		return
	var L: SystemLayout = m.view.layout
	for i in 120:
		if m.flight.can_fly():
			break
		await get_tree().process_frame
	var to := -9
	for b in L.bodies:
		if b.world != &"" and b.index != m.flight.reached():
			to = b.index
			break
	if SystemLayout.is_place(to):
		m.flight.plan_bg(to, m.view.t, {}, &"preview", 1600)
	print("  --   quitting with a flight plan being made on a worker: %s" % m.flight.planning(&"preview"))


## THE GIANT'S PAGE: its MASS line, "OF ITS STARS" in a twin, on a page that fits.
func _giant_page(n: MapGen.MapNode) -> void:
	var g: MapGen.MapNode = null
	for raw in Run.map:
		var c: MapGen.MapNode = raw
		if MapGen.twin_ok(c) and c.gas_giant and c.region != MapGen.Region.FAUNA:
			g = c
			break
	if not h._ok("an ordinary system with a giant (%s)" % (MapGen.star_name(g) if g != null else "none"), g != null):
		return
	for two: bool in [true, false]:
		var was := g.twin
		g.twin = two
		Run.at = g.index
		SystemMapScreen._parked.erase(g.index)
		var m := await _map()
		if m == null:
			h._fail("no map at the giant")
			g.twin = was
			continue
		var gi := -1
		for b in m.view.layout.bodies:
			if b.kind == &"giant":
				gi = b.index
		if not h._ok("the giant is laid out (#%d)" % gi, gi >= 0):
			g.twin = was
			continue
		m.select_body(gi)
		await _frames(3)
		var gb: SystemLayout.Body = m.view.layout.bodies[gi]
		var want := PanelS.mass_line(gb.gm_frac, two)
		var words := _words(m.panel._box)
		h._ok("%s: its page says MASS %s (gm_frac %.3f)" % ["two suns" if two else "one sun", want, gb.gm_frac],
			words.has("MASS") and words.has(want) and want.ends_with("OF ITS STARS" if two else "OF ITS STAR"))
		# NOTHING PRESSABLE MOVES: the page has the rows it had before ruling 20
		# (its facts less TYPE), MASS under GRAVITY in place of FAUNA, which a
		# giant never has, so its FLY HERE and the cards under it are where they
		# were (an extra row put them 13 px lower)
		var keys := _fact_keys(m.panel._box)
		var was_keys: Array[String] = []
		for f in m.view.facts(gb):
			if String(f[0]) != "TYPE" and String(f[0]) != "BEACONS":
				was_keys.append(String(f[0]))
		var gi2 := keys.find("GRAVITY")
		h._ok("%s: its %d fact rows are as many as before (%s), MASS under GRAVITY where FAUNA was (%s)" % ["two suns" if two else "one sun", keys.size(), ", ".join(was_keys), ", ".join(keys)],
			keys.size() == was_keys.size() and gi2 >= 0 and gi2 + 1 < keys.size() and keys[gi2 + 1] == "MASS" and not keys.has("FAUNA") and was_keys.has("FAUNA"))
		await _fit(m, "the giant's page, %s" % ("two suns" if two else "one sun"))
		if two:
			_saw("giant pages")
		g.twin = was
	Run.at = n.index


## A SHIP LEFT AT STAR B IN A SYSTEM WITH ONE SUN comes back at the star.
func _one_sun_fallback(n: MapGen.MapNode) -> void:
	var one: MapGen.MapNode = null
	for raw in Run.map:
		var c: MapGen.MapNode = raw
		if c.type == MapGen.NodeType.SYSTEM and not c.twin and c.index != n.index and c.region != MapGen.Region.FAUNA:
			one = c
			break
	if not h._ok("a system with one sun", one != null):
		return
	# (the map up now put away first, and out of the tree, its own record
	# written: it may be this one)
	Router.show_local()
	await _idle()
	await _frames(2)
	Run.at = one.index
	one.visited = true
	SystemMapScreen._parked[one.index] = {"at": SystemLayout.STAR_B, "mode": &"rail"}
	h._ok("its place reads as the star (%d)" % Run.site_here(one), Run.site_here(one) == -1)
	# (LOCAL first, from that record as it stands: its sky at the star's close
	# orbit, not open space at the edge)
	Router.show_local()
	await _idle()
	await _frames(2)
	var sc := Router.current as SectorScreen
	var sky: LocalSky = sc._view.backdrop if sc != null and sc._view != null else null
	h._ok("LOCAL's sky has the ship at the star too (%d)" % (sky.orbit_target if sky != null else -99), sky != null and sky.orbit_target == -1)
	var m := await _map()
	h._ok("and the map puts the ship in the star's close orbit (%d)" % (m.flight.reached() if m != null else -99), m != null and m.flight.reached() == -1)
	if m == null:
		return
	_one_sun_facts(m)
	# ONE SUN, PUT BACK ON ITS WIDE ORBIT: r 300 came back at 223 (the saves review)
	var L: SystemLayout = m.view.layout
	var r1 := clampf(300.0, L.star_ring_of(-1) + 40.0, L.edge * 0.8)
	await _put_back(one, _clear_at(m, r1, 0.4), -1, "one sun, round the star", false)
	m = Router.current as SystemMapScreen
	if m == null:
		return
	await _put_back(one, _clear_at(m, r1, 2.6), -1, "one sun, round the star, by the save's rows", true)
	await _mid_flight_tab(one, "one sun")
	await _restyle_mid_flight(one, "one sun")
	await _go_view_open(one, "one sun")


# ---------------------------------------------------------------- the stars' facts
## EACH STAR'S FACTS AS IT IS DRAWN (kept findings [23] and [27], Nov 1): star B
## read YELLOW DWARF, G2, 5,700 K, star A's, under the orange sun the map draws,
## and MASS read each star's share of the pair's pull (star A 0.55 SOL beside G2,
## which no G2 weighs). Now star A reads as the one sun does, and star B as the
## K5 orange dwarf its colour is nearest, with a K5's own MASS and RADIUS, 0.7
## SOL each (Jon, Nov 1, "starb:B"; they read its mass against A's as their
## pulls are, 0.72 to 0.92, and its drawn radius). The pulls are as they were.
## The sector page as it stands, star by star: its kind under its name, then
## CLASS, SURFACE, MASS and RADIUS.
func _page_facts(m: SystemMapScreen, nm: String) -> Dictionary:
	var words := _words(m.panel._box)
	var k := words.find(nm)
	var got := {}
	if k < 0 or k + 1 >= words.size():
		return got
	got["kind"] = words[k + 1]
	for j in range(k + 2, mini(k + 12, words.size() - 1)):
		if words[j] in ["CLASS", "SURFACE", "MASS", "RADIUS"] and not got.has(words[j]):
			got[words[j]] = words[j + 1]
	return got


## STAR B'S PULL AGAINST STAR A'S as the layout rolls it (`TWIN_SHARE_LO` to
## `_HI` of the pair's pull to star A): 0.724 to 0.923.
static func _pull_lo() -> float:
	return (1.0 - SystemLayout.TWIN_SHARE_HI) / SystemLayout.TWIN_SHARE_HI


static func _pull_hi() -> float:
	return (1.0 - SystemLayout.TWIN_SHARE_LO) / SystemLayout.TWIN_SHARE_LO


func _star_facts_page(m: SystemMapScreen) -> void:
	var L: SystemLayout = m.view.layout
	var one: Dictionary = SystemViewS.STAR_FACTS["ORDINARY"]
	var fa := _page_facts(m, m.overlay.star_name_of(-1))
	var fb := _page_facts(m, m.overlay.star_name_of(SystemLayout.STAR_B))
	h._ok("star A reads as one sun does: %s, %s, %s, MASS %s, RADIUS %s" % [fa.get("kind"), fa.get("CLASS"), fa.get("SURFACE"), fa.get("MASS"), fa.get("RADIUS")],
		fa.get("kind") == one.kind and fa.get("CLASS") == one.cls and fa.get("SURFACE") == one.temp and fa.get("MASS") == one.mass and fa.get("RADIUS") == one.radius)
	h._ok("star B reads as the K5 orange dwarf it is drawn as, a K5's own numbers: %s, %s, %s, MASS %s, RADIUS %s (want 0.7 SOL each)" % [fb.get("kind"), fb.get("CLASS"), fb.get("SURFACE"), fb.get("MASS"), fb.get("RADIUS")],
		fb.get("kind") == "ORANGE DWARF" and fb.get("CLASS") == "K5" and fb.get("SURFACE") == "4,400 K" and fb.get("MASS") == "0.7 SOL" and fb.get("RADIUS") == "0.7 SOL")
	# THE PULLS AS THEY WERE: the page's words only; a flight still feels star B
	# at its share of the pair's pull, 0.72 to 0.92 of star A's
	var pr := (1.0 - L.star_share) / L.star_share
	var g := MapGravity.from_layout(L)
	var ga := -1.0
	var gb := -1.0
	for k in g.star_id.size():
		if g.star_id[k] == -1:
			ga = g.star_gm[k]
		elif g.star_id[k] == SystemLayout.STAR_B:
			gb = g.star_gm[k]
	h._ok("and its pull is as built: B / A %.3f in the flight's gravity, %.3f from the shares, in %.3f to %.3f" % [gb / maxf(ga, 1e-9), pr, _pull_lo(), _pull_hi()],
		ga > 0.0 and gb > 0.0 and absf(gb / ga - pr) < 1e-6 and pr >= _pull_lo() - 1e-6 and pr <= _pull_hi() + 1e-6)
	_saw("star facts read off the page")


## EVERY TWIN OF THE RUN, made so where it may be: star A's facts the one sun's,
## word for word, and star B's a K5 orange dwarf's own, MASS and RADIUS 0.7 SOL
## in every one (Jon, Nov 1, "starb:B"), while the pulls' ratio B / A runs 0.72
## to 0.92 as built; and every one-sun system's facts its kind's table, as ever.
func _star_facts_all() -> void:
	var twins := 0
	var ones := 0
	var bad: Array[String] = []
	var p_lo := INF
	var p_hi := 0.0
	for raw in Run.map:
		var c: MapGen.MapNode = raw
		if c.type != MapGen.NodeType.SYSTEM and c.type != MapGen.NodeType.STATION and c.type != MapGen.NodeType.START:
			continue
		for two: bool in ([false, true] if MapGen.twin_ok(c) else [false]):
			var was := c.twin
			c.twin = two
			var L := SystemLayout.of(c)
			c.twin = was
			var kn: String = SystemViewS.KIND_NAMES[L.star]
			var fa: Dictionary = SystemViewS.star_facts_of(L, kn, -1)
			if fa != SystemViewS.STAR_FACTS[kn]:
				bad.append("%s star A %s" % [MapGen.star_name(c), fa])
			if not L.twin:
				ones += 1
				if SystemViewS.star_facts_of(L, kn, SystemLayout.STAR_B) != SystemViewS.STAR_FACTS[kn]:
					bad.append("%s one sun's star B" % MapGen.star_name(c))
				continue
			twins += 1
			var fb: Dictionary = SystemViewS.star_facts_of(L, SystemViewS.KIND_NAMES[L.star2], SystemLayout.STAR_B)
			var ratio := (1.0 - L.star_share) / L.star_share
			p_lo = minf(p_lo, ratio)
			p_hi = maxf(p_hi, ratio)
			if fb.kind != "ORANGE DWARF" or fb.cls != "K5" or fb.temp != "4,400 K" or fb.mass != "0.7 SOL" or fb.radius != "0.7 SOL":
				bad.append("%s star B %s (share %.3f)" % [MapGen.star_name(c), fb, L.star_share])
	h._ok("every twin's star A reads as one sun, its star B an orange dwarf K5 of MASS 0.7 SOL and RADIUS 0.7 SOL, while B pulls %.2f to %.2f of A as built; %d twins, %d one-sun systems their kind's own%s" % [
		p_lo, p_hi, twins, ones, "" if bad.is_empty() else ": " + "; ".join(bad.slice(0, 4))], bad.is_empty() and twins > 20 and ones > 20 and p_lo >= _pull_lo() - 1e-6 and p_hi <= _pull_hi() + 1e-6)
	_saw("twins' star facts", twins)


## A SYSTEM WITH ONE SUN'S PAGE, as it always read: its kind's own facts.
func _one_sun_facts(m: SystemMapScreen) -> void:
	m.panel_back()
	var sf: Dictionary = SystemViewS.STAR_FACTS[m.view.kind]
	var got := _page_facts(m, m.view.star_name())
	h._ok("one sun (%s): its page reads %s, %s, %s, MASS %s, RADIUS %s, its kind's own" % [m.view.kind, got.get("kind"), got.get("CLASS"), got.get("SURFACE"), got.get("MASS"), got.get("RADIUS")],
		got.get("kind") == sf.kind and got.get("CLASS") == sf.cls and got.get("SURFACE") == sf.temp and got.get("MASS") == sf.mass and got.get("RADIUS") == sf.radius)


## EVERY BODY OF A TWIN SAYS WHAT IT GOES AROUND (`SystemView.facts`): AROUND
## under ORBIT, never ROUND (Nov 1: the game says "around", never "round" in
## that sense), and its widest row, label and value, inside the text column.
func _around_rows() -> void:
	var font := UITheme.pixel_font()
	var rows := 0
	var bad: Array[String] = []
	var best := 0.0
	var best_say := ""
	for raw in Run.map:
		var c: MapGen.MapNode = raw
		if not MapGen.twin_ok(c):
			continue
		var was := c.twin
		c.twin = true
		var v: SystemViewS = SystemViewS.new()
		v.node = c
		v.layout = SystemLayout.of(c)
		c.twin = was
		for b in v.layout.bodies:
			var f: Array = v.facts(b)
			var keys: Array[String] = []
			for r: Array in f:
				keys.append(String(r[0]))
			var oi := keys.find("ORBIT")
			if oi < 0:
				continue
			rows += 1
			if oi + 1 >= keys.size() or keys[oi + 1] != "AROUND" or keys.has("ROUND") or String(f[oi + 1][1]) != v.host_line(b):
				bad.append("%s: %s" % [b.name, ", ".join(keys)])
				continue
			# (a row is its label, a spacer and its value: an HBox's two gaps of 4)
			var w := font.get_string_size("AROUND", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x \
				+ font.get_string_size(String(f[oi + 1][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x + 8.0
			if w > best:
				best = w
				best_say = "AROUND %s (%s)" % [f[oi + 1][1], b.name]
		v.free()
	var lw := font.get_string_size("AROUND", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
	h._ok("every twin body's facts say AROUND what it circles, never ROUND (%d rows); the label %.0f px, the widest row %.0f px of the %d: %s%s" % [
		rows, lw, best, PanelS.TEXT_W, best_say, "" if bad.is_empty() else "; " + "; ".join(bad.slice(0, 4))],
		bad.is_empty() and rows > 100 and best <= PanelS.TEXT_W)


# ---------------------------------------------------------------- the giants
## EVERY GIANT'S MASS LINE: 1/n, n the whole number nearest 1 / gm_frac, in
## the range it is rolled in, OF ITS STARS round two suns.
func _mass_lines() -> void:
	var giants := 0
	var twin_giants := 0
	var bad: Array[String] = []
	var ns := {}
	for raw in Run.map:
		var c: MapGen.MapNode = raw
		if not c.gas_giant:
			continue
		for two: bool in ([false, true] if MapGen.twin_ok(c) else [false]):
			var was := c.twin
			c.twin = two
			var L := SystemLayout.of(c)
			c.twin = was
			for b in L.bodies:
				if b.kind != &"giant":
					continue
				giants += 1
				if L.twin:
					twin_giants += 1
				var s := PanelS.mass_line(b.gm_frac, L.twin)
				var k := roundi(1.0 / b.gm_frac)
				ns[k] = true
				if s != "1/%d OF ITS STAR%s" % [k, "S" if L.twin else ""] or k < 4 or k > 10:
					bad.append("%s %.3f: %s" % [MapGen.star_name(c), b.gm_frac, s])
	var nk: Array = ns.keys()
	nk.sort()
	_saw("twin giants", twin_giants)
	h._ok("every giant's MASS line is 1/n of its star or stars (%d giants, %d round two suns, n in %s)%s" % [giants, twin_giants, nk,
		"" if bad.is_empty() else ": " + "; ".join(bad.slice(0, 4))], bad.is_empty() and giants > 0 and twin_giants > 0)


# ---------------------------------------------------------------- the looks sheet's picks
## Jon's picks from the twin looks sheet (Nov 1: "Twin looks: ring:A mass:A
## transit:A key:A list:C city:A letgo:A starb:B", and "Let's call it Binary
## instead of two suns"). starb:B is `_star_facts_page` and `_star_facts_all`.

## The numeral a body's name ends in, as an index into `SystemLayout.ROMAN` (I
## is 0), or ROMAN's size for a name with none.
static func _numeral(nm: String) -> int:
	var k := SystemLayout.ROMAN.find(nm.get_slice(" ", nm.get_slice_count(" ") - 1))
	return k if k >= 0 else SystemLayout.ROMAN.size()


## THE SATELLITES LIST IN NAME ORDER ("list:C"): every system of the run, laid
## out each way it may be, lists its bodies (`SystemLayout.name_order`) with the
## numerals of their names going up, I, II, III (past X, which ROMAN stops at,
## X again); round one sun that is the order they were made in, so nothing there
## moves. The binaries whose made order was not their names' are counted: the
## list read III, IV, I, V, II, VI in some.
func _name_order_all() -> void:
	var twins := 0
	var ones := 0
	var moved := 0
	var bad: Array[String] = []
	for raw in Run.map:
		var c: MapGen.MapNode = raw
		for two: bool in ([false, true] if MapGen.twin_ok(c) else [false]):
			var was := c.twin
			c.twin = two
			var L := SystemLayout.of(c)
			c.twin = was
			var order := L.name_order()
			var made: Array[int] = []
			for i in L.bodies.size():
				made.append(i)
			var ok := order.size() == made.size()
			for k in range(1, order.size()):
				var a := _numeral(L.bodies[order[k - 1]].name)
				var b := _numeral(L.bodies[order[k]].name)
				if b < a or (b == a and b < SystemLayout.ROMAN.size() - 1):
					ok = false
			if L.twin:
				twins += 1
				if order != made:
					moved += 1
			else:
				ones += 1
				if order != made:
					ok = false
			if not ok:
				var nms := PackedStringArray()
				for i: int in order:
					nms.append(L.bodies[i].name)
				bad.append("%s (%s): %s" % [MapGen.star_name(c), "binary" if L.twin else "one sun", ", ".join(nms)])
	_saw("layouts' SATELLITES in name order", twins + ones)
	h._ok("every system lists its SATELLITES in name order: %d binaries (%d of them not in the order they were made), %d with one sun, all in the order they were made%s" % [
		twins, moved, ones, "" if bad.is_empty() else ": " + "; ".join(bad.slice(0, 4))],
		bad.is_empty() and twins > 20 and ones > 20 and moved > 0)


## AND ON THE PAGE: the sector page's SATELLITES rows, read off it in order, are
## the bodies in name order.
func _satellites_page(m: SystemMapScreen) -> void:
	m.panel_back()
	var L: SystemLayout = m.view.layout
	var words := _words(m.panel._box)
	var k := -1
	for i in words.size():
		if words[i].begins_with("SATELLITES · "):
			k = i
	var names := {}
	for b in L.bodies:
		names[b.name] = true
	var got := PackedStringArray()
	if k >= 0:
		for j in range(k + 1, words.size()):
			if names.has(words[j]):
				got.append(words[j])
	var want := PackedStringArray()
	for i: int in L.name_order():
		want.append(L.bodies[i].name)
	var made := PackedStringArray()
	for b in L.bodies:
		made.append(b.name)
	h._ok("the sector page lists its SATELLITES in name order: %s (made %s)" % [", ".join(got), ", ".join(made)],
		k >= 0 and got == want and got.size() == L.bodies.size())
	_saw("SATELLITES pages read")


## The code on a line of GDScript or a scene, its comment left off (a # outside
## a string).
static func _code_of(line: String) -> String:
	var q := ""
	var i := 0
	while i < line.length():
		var ch := line[i]
		if q != "":
			if ch == "\\":
				i += 1
			elif ch == q:
				q = ""
		elif ch == "\"" or ch == "'":
			q = ch
		elif ch == "#":
			return line.substr(0, i)
		i += 1
	return line


static func _files_under(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".tres") or f.ends_with(".json"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_files_under(dir.path_join(sub), out)


## NO STRING A PLAYER READS SAYS TWO SUNS ("Let's call it Binary instead of two
## suns"): every string in the game's scripts, scenes and data, the harnesses and
## comments left out, read for "two suns", "two-sun", "second sun" and "both
## suns". The sector page, the HUD's tip (`_stars_as_places`) and the chart's
## STAR row (`MapGen.BINARY`) say binary; a world round the pair, and a ship
## settled round it, say BOTH STARS (the AROUND row read BOTH SUNS beside the
## page's BINARY, the picks review, Nov 1).
func _no_two_suns_said() -> void:
	var re := RegEx.create_from_string("(?i)\"[^\"]*\\b(two[ -]suns?|second sun|both suns)\\b[^\"]*\"")
	var files: Array[String] = []
	for top: String in ["res://scripts", "res://scenes", "res://data"]:
		_files_under(top, files)
	var said: Array[String] = []
	var lines := 0
	var read := 0
	for p: String in files:
		if p.begins_with("res://scripts/sim/"):
			continue
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			continue
		read += 1
		var ln := 0
		while not f.eof_reached():
			var code := _code_of(f.get_line())
			ln += 1
			if code.strip_edges() == "":
				continue
			lines += 1
			var mm := re.search(code)
			if mm != null:
				said.append("%s:%d %s" % [p.get_file(), ln, mm.get_string()])
	h._ok("no string a player reads says two suns or both suns (%d files, %d lines of code read), and a binary is called %s%s" % [read, lines, MapGen.BINARY,
		"" if said.is_empty() else ": " + "; ".join(said.slice(0, 4))], said.is_empty() and read > 100 and MapGen.BINARY == "BINARY")


## THE SHIP ON A RING, frame by frame (`SystemOverlay.ship_px`): over `frames`
## frames, every `every`th, with world `w` the ring it rides. Counts the frames
## looked at, those with any of the hull drawn and those with the light outline
## (&"rim"); the outline's pixels in another colour, on the hull's shape or not
## beside it; the hull's pixels hidden by nothing but its own world (any other
## world's disc or a sun's explains one); and the frames with the ship's middle
## on its own world's drawn disc, where it sat hidden in part before ring:A.
func _ring_frames(m: SystemMapScreen, w: int, frames: int, every: int) -> Dictionary:
	var ov = m.overlay
	var L: SystemLayout = m.view.layout
	var r := {"seen": 0, "hull": 0, "rim": 0, "rim_px": 0, "colour": 0, "on_hull": 0, "apart": 0, "own_hid": 0, "on_disc": 0, "ringed": 0}
	ov.record_px = true
	for f in frames:
		await get_tree().process_frame
		if f % every != every - 1:
			continue
		r.seen += 1
		if ov.ringed_world() == w:
			r.ringed += 1
		var pic: Dictionary = ov.hull_pic
		if pic.is_empty():
			continue
		var x: Vector2 = ov._ship_at
		var tp: Dictionary = MapHullS.turned(pic, MapHullS.bin_of(m.flight.ang))
		var shape := {}
		for o: Vector2 in (tp.o as PackedVector2Array):
			shape[Vector2i((x + o).round())] = true
		var drawn := {}
		var rims: Array[Vector2i] = []
		for e: Array in ov.ship_px:
			var q := Vector2i((e[0] as Vector2).round())
			if e[2] == &"hull" or e[2] == &"outline":
				drawn[q] = true
			elif e[2] == &"rim":
				rims.append(q)
				if (e[1] as Color) != OverlayS.RING_OUTLINE:
					r.colour += 1
		if not drawn.is_empty():
			r.hull += 1
		if not rims.is_empty():
			r.rim += 1
		r.rim_px += rims.size()
		for q: Vector2i in rims:
			if shape.has(q):
				r.on_hull += 1
			elif not (shape.has(q + Vector2i(1, 0)) or shape.has(q - Vector2i(1, 0)) or shape.has(q + Vector2i(0, 1)) or shape.has(q - Vector2i(0, 1))):
				r.apart += 1
		# (a frame with the hull over its world's disc, so "never hidden" was asked
		# of it: by its pixels, not its middle -- the ring's near point is about
		# the disc's own radius from the world's middle at the opening zoom, so the
		# middle came onto the disc in a few frames or none by the rounding alone,
		# 4 of 60 with the pair held still and 0 once it turns, ruling 23)
		var over := false
		for q: Vector2i in shape:
			if w >= 0 and Vector2(q).distance_to(m.view.at[w]) < m.view.draw_r(L.bodies[w]) - 0.5:
				over = true
				break
		if over:
			r.on_disc += 1
		for q: Vector2i in shape:
			if drawn.has(q):
				continue
			var qv := Vector2(q)
			var why := false
			for s: int in L.stars():
				if qv.distance_to(ov.star_scr(s)) < float(ov.star_disc(s)) + 0.5:
					why = true
			for j: int in m.view._views:
				if j != w and qv.distance_to(m.view.at[j]) < m.view.draw_r(L.bodies[j]) + 0.5:
					why = true
			if not why:
				r.own_hid += 1
	ov.record_px = false
	return r


## THE SHIP ON ITS SMALL WORLD'S RING, OUTLINED ("ring:A"): on the ring of the
## world round star A, at the opening zoom, for a lap and more, the ship wears a
## 1 px light outline (`SystemOverlay.RING_OUTLINE`) round its hull and never on
## it, in every frame any of the hull shows, and no pixel of the hull is hidden
## by its own world (on the far side of the ring it hid part of it).
func _ring_outline_open(m: SystemMapScreen, wa: int) -> void:
	var r := await _ring_frames(m, wa, 180, 3)
	h._ok("on the ring of %s round star A the ship is outlined in light: %d of %d frames with the hull drawn have it (%d px, %d off colour, %d on the hull, %d not beside it)" % [
		m.view.layout.bodies[wa].name, r.rim, r.hull, r.rim_px, r.colour, r.on_hull, r.apart],
		r.ringed == r.seen and r.hull > 0 and r.rim == r.hull and r.colour == 0 and r.on_hull == 0 and r.apart == 0)
	h._ok("and its own world never hides it: %d hull pixels hidden by nothing else, over %d frames, %d with the hull over the world's disc" % [r.own_hid, r.seen, r.on_disc],
		r.own_hid == 0 and r.on_disc > 0)
	_saw("rings outlined, frames", r.seen)


## WHERE THE FLIGHT DRAWN BEFORE IT IS FLOWN ENDS, flown to a world round star B
## from the ring of the world round star A (the review of the plan, PLAUSIBLE:
## at Kepler x 4 those two worlds go round their suns four times as fast, and
## their suns turn, so the line's end, round where the world will be when the
## ship gets there, `SystemOverlay._ends_table` at the plan's own moments,
## stands off where it is drawn now): printed, not judged, for Jon to see; and
## a ring drawn there goes behind the world's disc as drawn now, judged.
func _preview_end_gap(m: SystemMapScreen, wa: int) -> void:
	var ov = m.overlay
	var v = m.view
	var L: SystemLayout = v.layout
	var wb := -1
	for b in L.bodies:
		if wb < 0 and b.host_id == SystemLayout.STAR_B and b.world != &"":
			wb = b.index
	if wb < 0 or m.flight.reached() != wa:
		return
	ov.selected = wb
	var got := false
	for i in 600:
		await get_tree().process_frame
		if ov._pv_plan != null and ov._pv_plan.res != null and int(ov._pv_plan.to) == wb:
			got = true
			break
	if got:
		var pl = ov._pv_plan
		var t_arr: float = m.flight._arrive_t(pl)
		var now3: Vector3 = m.flight.center(wb, v.t)
		var then3: Vector3 = m.flight.center(wb, t_arr)
		var gap: float = (v.screen(now3.x, now3.z) as Vector2).distance_to(v.screen(then3.x, then3.z))
		print("  --   the flight drawn to %s (round star B) ends round where it will be in %.1f s, %.1f px on screen from where it is drawn now (zoom %.3f, %.1f plane px)" % [
			L.bodies[wb].name, t_arr - float(v.t), gap, v.zoom, Vector2(now3.x, now3.z).distance_to(Vector2(then3.x, then3.z))])
		# THE RING ROUND WHERE IT WILL BE (as the let-go forecast draws its orbit
		# there, `SystemOverlay._line`), dashed and solid: its far half never
		# crosses the world's disc as it is drawn now. Cut only round its own
		# centre, 7.8 px off the drawn world at the opening zoom, it was drawn
		# across the world's face (review 1, Nov 2)
		var cw: Vector2 = v.screen(then3.x, then3.z)
		var wd: Vector2 = v.at[wb]
		var disc: float = v.draw_r(L.bodies[wb])
		var rpx: float = ov._orbit_px(wb, m.flight.orbit_r(wb))
		var on := 0
		var could := 0
		for dashed: bool in [true, false]:
			for q: Vector2 in ov.ring_pts(cw, rpx, wb, dashed):
				if q.y < cw.y - 0.5 and q.distance_to(wd) < disc - 0.5:
					on += 1
		# (and how many of its far half's points lie on that disc, uncut)
		var n_r := int(rpx * 6.4) + 24
		for j in n_r:
			var an := float(j) / float(n_r) * TAU
			var q2 := cw + Vector2(cos(an) * rpx, sin(an) * rpx * v.TILT)
			if sin(an) < 0.0 and q2.distance_to(wd) < disc and q2.distance_to(cw) >= disc:
				could += 1
		h._ok("the ring round where %s will be is cut behind its disc as drawn now: %d far-side pixels on it (%d of the ring's points lie there, %.1f px off its centre)" % [L.bodies[wb].name, on, could, gap], on == 0)
	else:
		print("  --   no flight drawn to the world round star B in 10 s, its end not measured")
	ov.selected = -2
	await _frames(2)


## THE WORDS BY THE SHIP HOLD STILL AS IT RIDES ITS RING: in OMEGA CALLOUS REACH
## (seed 7, node 284), on the ring of its first world round star A (OMEGA
## CALLOUS I), the world selected as in the picks stills, at the opening zoom,
## the clock running for `RIDE_FRAMES` frames (about two orbits). The words are
## there every frame and, measured from where their world is drawn (it goes
## round its sun, carried as its sun turns: ruling 23), never move more than 3
## px from one frame to the next, and spread no more than 3 px each way over the
## ride.
## Stepped off a sun and the beacon there, nearest first under the ring, above
## it and under the ship together, they hopped 6 to 10 px between under the
## ring and under the ship about twice an orbit and slid with the ship between
## (the review of 19fd37e5, Nov 1); still, as they stood on b764c344, on the
## beacon.
const RIDE_FRAMES := 400


func _ring_words_ride() -> void:
	Router.show_local()
	await _idle()
	await _frames(2)
	Rng.forced = 7
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n: MapGen.MapNode = Run.map[284] if Run.map.size() > 284 else null
	if not h._ok("seed 7's node 284 is a binary to ride a ring in (%s)" % (MapGen.star_name(n) if n != null else "none"),
			n != null and n.twin and MapGen.twin_ok(n)):
		return
	var wa := -1
	for b in SystemLayout.of(n).bodies:
		if wa < 0 and b.host_id == -1 and b.world != &"":
			wa = b.index
	if not h._ok("it has a world round star A (#%d)" % wa, wa >= 0):
		return
	Run.at = n.index
	n.visited = true
	SystemMapScreen._parked[n.index] = {"at": wa, "mode": &"rail"}
	var m := await _map()
	if not h._ok("the map comes up in %s for the ride" % MapGen.star_name(n), m != null and m.view.node == n):
		return
	var ov = m.overlay
	m.view.t = 40.0
	m.flight.place_at(wa, m.view.t)
	ov.selected = wa
	await _frames(40)
	var full: String = "IN ORBIT · " + String(ov._place_nm(wa))
	var ang0 := float(m.flight.rail.get("ang", 0.0))
	var seen := 0
	var hops := 0
	var biggest := 0.0
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var last := Rect2()
	for f in RIDE_FRAMES:
		await get_tree().process_frame
		var box := _said_box(ov, full)
		if box.size.x <= 0.0:
			box = _said_box(ov, full.get_slice(" · ", 0))
		if box.size.x <= 0.0:
			last = Rect2()
			continue
		seen += 1
		# (from the world as drawn, `SystemOverlay._body_scr`, which the words
		# under its ring are centred on)
		box.position -= ov._body_scr(wa) as Vector2
		if last.size.x > 0.0:
			var d := box.position.distance_to(last.position)
			biggest = maxf(biggest, d)
			if d > 3.0:
				hops += 1
		lo = lo.min(box.position)
		hi = hi.max(box.position)
		last = box
	var turns := absf(float(m.flight.rail.get("ang", 0.0)) - ang0) / TAU
	ov.selected = -2
	var spread := hi - lo if seen > 0 else Vector2.INF
	h._ok("riding the ring of %s for %.1f orbits, %s selected, the words by the ship hold still by it: there in %d of %d frames, %d moves over 3 px (the most %.1f px), spread %s px from %s off it" % [
		ov._place_nm(wa), turns, ov._place_nm(wa), seen, RIDE_FRAMES, hops, biggest, spread, lo],
		seen == RIDE_FRAMES and hops == 0 and spread.x <= 3.0 and spread.y <= 3.0 and turns >= 1.5)
	_saw("ring rides, frames", seen)
	await _close_b_words_ride()


## THE WORDS BY THE SHIP DO NOT FLICKER AT A BEACON'S EDGE (review 2): in star
## B's close orbit of seed 7's close pair (system 41, ZETA VESPER-4) from map
## time 97 to 107, the beacon on a world round both suns creeps along the
## words' left end as star B carries the words the same way. They stepped 16 px
## down off it, back up as it cleared by a hair and down again, three hops in
## 4 s; stepped off, they now go back only once their first spot clears by
## `SystemOverlay.WORDS_BACK_PX`. At most the one step off, never back and forth.
func _close_b_words_ride() -> void:
	var B := SystemLayout.STAR_B
	var n: MapGen.MapNode = Run.map[41] if Run.map.size() > 41 else null
	if not h._ok("seed 7's node 41 is a close pair to ride star B's close orbit in (%s)" % (MapGen.star_name(n) if n != null else "none"),
			n != null and SystemLayout.of(n).twin and SystemLayout.of(n).close):
		return
	Router.show_local()
	await _idle()
	await _frames(2)
	Run.at = n.index
	n.visited = true
	n.ambush_pending = false
	SectorScreen._approached_at = n.index
	Run.map_clock[n.index] = 97.0
	SystemMapScreen._parked[n.index] = {"at": B, "mode": &"rail"}
	var m := await _map()
	if not h._ok("the map comes up in %s in star B's close orbit" % MapGen.star_name(n), m != null and m.view.node == n and m.flight.reached() == B):
		return
	var ov = m.overlay
	m.view.t = 97.0
	var full: String = "CLOSE ORBIT · " + String(ov._place_nm(B))
	var hops := 0
	var back := 0
	var seen := 0
	var spots: Array[Vector2] = []
	var last := Rect2()
	while m.view.t < 107.0:
		await get_tree().process_frame
		var box := _said_box(ov, full)
		if box.size.x <= 0.0:
			last = Rect2()
			continue
		seen += 1
		box.position -= ov._body_scr(B) as Vector2
		if last.size.x > 0.0 and box.position.distance_to(last.position) > 3.0:
			hops += 1
			# (back to a spot it had stood at: a flicker)
			for q in spots:
				if box.position.distance_to(q) <= 3.0:
					back += 1
					break
			spots.append(last.position)
		last = box
	h._ok("in star B's close orbit of %s, map time 97 to 107, the words by the ship step at most once and never back (%d moves over 3 px, %d back; seen %d frames)" % [
		MapGen.star_name(n), hops, back, seen], seen > 0 and hops <= 1 and back == 0)


## THE EDGE ARROW'S LOOK (Jon, Nov 5: "make the icon the same height as the
## arrow and make the arrow hollow"), for each of the eight ways, drawn by
## `SystemOverlay._tri_queue` alone: the key glyph in 2 px cells, as tall across
## the arrow's axis as a side arrow is (10 px), centred on that axis, and on a
## diagonal arrow centred on its middle line; the arrow's inside (`tri_px`
## cells with all four neighbours in it) never in the arrow's colour, only the
## dark ring just inside its line, and nothing at all further in.
func _arrow_shapes() -> void:
	var ov = OverlayS.new()
	var col := Color("#9b8ec8")
	var bad: Array[String] = []
	var deep_n := 0
	for dir: Vector2i in [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]:
		var bx: Array = ov._tri_boxes(Vector2.ZERO, dir, true)
		var ab: Rect2 = (bx[1] as Rect2).grow(-1.0)
		var gb: Rect2 = bx[2]
		var diag := dir.x != 0 and dir.y != 0
		# (across the axis: a side arrow's height pointing left or right, its
		# width pointing up or down)
		var a_across := ab.size.y if dir.y == 0 else ab.size.x
		var g_across := gb.size.y if dir.y == 0 else gb.size.x
		var off := Vector2(dir).normalized().cross(gb.get_center() - ab.get_center())
		if diag:
			if gb.size != Vector2(10, 10) or absf(off) > 0.5:
				bad.append("%s: the glyph %s, %.1f px off the arrow's middle line" % [dir, gb.size, off])
		elif g_across != a_across or absf(off) > 0.01:
			bad.append("%s: the glyph %.0f px across the axis, the arrow %.0f; %.1f px off its axis" % [dir, g_across, a_across, off])
		# the inside, from the solid triangle
		var solid := {}
		for p: Vector2i in OverlayS.tri_px(dir):
			solid[p] = true
		var inside := {}
		for p: Vector2i in solid:
			if solid.has(p + Vector2i.RIGHT) and solid.has(p + Vector2i.LEFT) and solid.has(p + Vector2i.UP) and solid.has(p + Vector2i.DOWN):
				inside[p] = true
		var by_line := {}
		for p: Vector2i in inside:
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var n := p + Vector2i(dx, dy)
					if solid.has(n) and not inside.has(n):
						by_line[p] = true
		ov.mark_rects = []
		ov._tri_queue(Vector2.ZERO, dir, col, true, &"contract")
		var drawn := {}
		for e: Array in ov.mark_rects:
			drawn[Vector2i((e[0] as Rect2).position)] = e[1]
		var lit := 0
		var deep := 0
		for p: Vector2i in inside:
			if drawn.has(p) and (drawn[p] as Color).is_equal_approx(col):
				lit += 1
			if not by_line.has(p):
				deep_n += 1
				if drawn.has(p):
					deep += 1
		if lit > 0 or deep > 0 or inside.is_empty():
			bad.append("%s: %d of its %d inside pixels in its colour, %d of those off its line drawn" % [dir, lit, inside.size(), deep])
	ov.free()
	h._ok("each of the eight edge arrows: its key glyph as tall as the arrow (10 px, 2 px cells), centred on its axis or middle line, and the arrow hollow, its inside never in its colour and, past the dark ring inside its line, not drawn (%d such pixels)%s" % [
		deep_n, "" if bad.is_empty() else ": " + "; ".join(bad)], bad.is_empty() and deep_n > 0)


## A WIDE PAIR OPENS FRAMED ON ITS OWN PART (Jon, Nov 1, "gap:A"), as the ring
## sweep shows each wide pair (`_pair_marks`): at `SystemMapScreen.open_view`,
## nearer than the whole system and centred on the two suns and their own
## worlds; each world round one sun drawn PAIR_GAP_LEAST px or more clear of its
## sun's disc beside it (fitted to the whole system it was 5 px, seed 7); every
## event's beacon off the picture with an arrow at the frame's edge
## (`SystemOverlay.edge_marks`), each inside the frame and over nothing drawn
## there: the words, the beacons, the suns, the worlds, your ship, the status
## line, the goal, the instrument or another arrow.
const PAIR_GAP_LEAST := 24.0


func _pair_marks(m: SystemMapScreen, sd: int, n: MapGen.MapNode, st: Dictionary, bad: Array[String]) -> void:
	var v = m.view
	var ov = m.overlay
	var L: SystemLayout = v.layout
	var win: Rect2 = v.window
	var nm := "seed %d %s" % [sd, MapGen.star_name(n)]
	st.wide += 1
	# (the pair alone, on the frame it opened on: the layout's before the frame
	# is laid out, the frame's after; a ship put back off it widens it)
	var za := float(SystemMapScreen.open_view(L, n, m._frame.size, Run.map_t(n.index)).zoom)
	var zb := float(SystemMapScreen.open_view(L, n, SystemLayout.FIT_FRAME, Run.map_t(n.index)).zoom)
	if v.zoom != m.open_zoom or m.open_zoom > maxf(za, zb) + 1e-9 or m.open_zoom < m.zoom_min * 1.5 or m._look_at().distance_to(m.home_at) > 0.5:
		st.zoom_bad += 1
		bad.append("%s: opened at %.4f (open_view %.4f / %.4f, whole %.4f), looking at %s, home %s" % [nm, v.zoom, za, zb, m.zoom_min, m._look_at(), m.home_at])
	for p: int in L.stars():
		var w: SystemLayout.Body = null
		for b in L.bodies:
			if b.host_id == p and b.world != &"" and (w == null or b.orbit < w.orbit):
				w = b
		if w != null:
			st.gap_n += 1
			st.gap_least = minf(st.gap_least, w.orbit * v.zoom - v.star_disc(p) - v.draw_r(w))
	# THE PAIR ON THE PICTURE at the clock it opened at (ruling 23: each binary
	# here opens at another of LAP_CLOCKS angles): both suns' discs and every
	# world round one sun as drawn, inside the frame
	var whole := true
	for p: int in L.stars():
		var r: float = ov.star_disc(p)
		whole = whole and win.encloses(Rect2(ov.star_scr(p) - Vector2(r, r), Vector2(r, r) * 2.0))
	for b in L.bodies:
		if SystemLayout.is_star(b.host_id) and b.world != &"":
			var r: float = maxf(v.draw_r(b), 2.0)
			whole = whole and win.encloses(Rect2(v.at[b.index] - Vector2(r, r), Vector2(r, r) * 2.0))
	if not whole:
		st.framed_off += 1
		bad.append("%s at t %.0f (%.0f deg round): the pair not all on the picture %s" % [nm, v.t, rad_to_deg(L.pair_n * float(v.t)), win])
	# what is drawn there, which an arrow must not be on
	var drawn: Array = (ov.label_rects as Array).duplicate()
	drawn.append_array(ov.mark_keep)
	var stat: Array = ov.ship_status()
	if String(stat[0]) != "":
		drawn.append(ov.status_rect(String(stat[0])))
	for e in ov.beacons_at:
		var bb: Rect2 = OverlayS.beacon_box(e[0])
		if bb.intersects(win):
			drawn.append(bb)
		else:
			st.off += 1
	for p: int in L.stars():
		var r: float = ov.star_disc(p)
		drawn.append(Rect2(ov.star_scr(p) - Vector2(r, r), Vector2(r, r) * 2.0))
	for i in L.bodies.size():
		var b := L.bodies[i]
		if b.kind != &"belt":
			var r: float = maxf(v.draw_r(b), 2.0)
			drawn.append(Rect2(v.at[i] - Vector2(r, r), Vector2(r, r) * 2.0))
	var sr := float(ov.ship_r())
	drawn.append(Rect2(ov._ship_at - Vector2(sr, sr), Vector2(sr, sr) * 2.0))
	var boxes: Array = []
	# (what the screen draws for the arrows, by pixel: the look as drawn, Jon's
	# Nov 5 `_arrow_shapes`)
	var px_at := {}
	for e: Array in ov.mark_rects:
		px_at[Vector2i((e[0] as Rect2).position)] = e[1]
	for mk: Dictionary in ov.edge_marks:
		st.marks += 1
		if int(mk.body) != -9:
			st.marked += 1
		var dir: Vector2i = mk.dir
		var ab: Rect2 = (mk.arrow_box as Rect2).grow(-1.0)
		var gb: Rect2 = mk.glyph_box
		var looks := true
		if gb.has_area() and dir.x * dir.y == 0 and (gb.size.y if dir.y == 0 else gb.size.x) != (ab.size.y if dir.y == 0 else ab.size.x):
			looks = false
			bad.append("%s: the arrow at %s pointing %s has its glyph %s beside the arrow's %s" % [nm, mk.at, dir, gb.size, ab.size])
		var solid := {}
		for p: Vector2i in OverlayS.tri_px(dir):
			solid[p] = true
		var q := Vector2i((mk.at as Vector2).round())
		for p: Vector2i in solid:
			if solid.has(p + Vector2i.RIGHT) and solid.has(p + Vector2i.LEFT) and solid.has(p + Vector2i.UP) and solid.has(p + Vector2i.DOWN):
				var c: Variant = px_at.get(q + p)
				if c != null and not Color(c).is_equal_approx(Color(OverlayS.MARK_DARK, Color(c).a)):
					looks = false
					bad.append("%s: the arrow at %s pointing %s is filled at %s" % [nm, mk.at, dir, p])
					break
		if not looks:
			st.look_bad += 1
		# (an event's arrow carries its key glyph, a ship's none: "Edge arrows: C")
		if (StringName(mk.glyph) != &"") != (int(mk.body) != -9) or (StringName(mk.glyph) != &"") != (mk.glyph_box as Rect2).has_area():
			st.untagged += 1
			bad.append("%s: the arrow at %s for %d carries glyph '%s'" % [nm, mk.at, int(mk.body), mk.glyph])
		var mb: Rect2 = mk.box
		var on := not win.encloses(mb)
		for r: Rect2 in drawn + boxes:
			if r.intersects(mb):
				on = true
		boxes.append(mb)
		if on:
			st.mark_on += 1
			bad.append("%s: the arrow at %s for %d is on something drawn" % [nm, mk.at, int(mk.body)])


## THE NEARER SUN TAKES THE CLICK (ruling 23, "stacked:A": a close pair turns
## through standing one sun in front of the other, the near one drawn over the
## far), on this close pair's map at its opening zoom: over a lap of the pair,
## the moment the suns' discs overlap most with each sun in front; there, a
## click between their middles, on both discs, is on the nearer sun
## (`SystemOverlay.hit`, the suns nearest first). Tried in fixed order, star A
## first, the click went to star A behind star B's face. A pair whose discs
## never meet at this zoom is counted, not judged.
func _nearer_hit(m: SystemMapScreen, sd: int, n: MapGen.MapNode, st: Dictionary, bad: Array[String]) -> void:
	var v = m.view
	var ov = m.overlay
	var L: SystemLayout = v.layout
	if L.pair_n <= 0.0:
		return
	var B := SystemLayout.STAR_B
	var lap := TAU / L.pair_n
	var t0: float = v.t
	var best := {-1: [0.0, 0.0], B: [0.0, 0.0]}
	for k in 720:
		var t := t0 + lap * float(k) / 720.0
		var pa := L.star_pos(-1, t)
		var pb := L.star_pos(B, t)
		var sa: Vector2 = v.block_round(v.screen(pa.x, pa.y))
		var sbp: Vector2 = v.block_round(v.screen(pb.x, pb.y))
		var meet: float = float(ov.star_disc(-1)) + float(ov.star_disc(B)) - sa.distance_to(sbp)
		var front := -1 if v.depth(pa) > v.depth(pb) else B
		if meet > float(best[front][0]):
			best[front] = [meet, t]
	m.frozen = true
	for front: int in [-1, B]:
		if float(best[front][0]) < 2.0:
			st.near_none += 1
			continue
		v.t = float(best[front][1])
		await _frames(2)
		var a: Vector2 = ov.star_scr(-1)
		var b: Vector2 = ov.star_scr(B)
		var da: float = ov.star_disc(-1)
		var db: float = ov.star_disc(B)
		var d := a.distance_to(b)
		var q := a if d < 0.01 else a + (b - a) / d * clampf((d + da - db) * 0.5, 0.0, d)
		var hh: Dictionary = ov.hit(q)
		st.near_n += 1
		if hh.get("kind", &"") != &"star" or int(hh.get("body", -99)) != front:
			st.near_bad += 1
			bad.append("seed %d %s at t %.0f, star %d in front (the discs %.1f px over each other): a click at %s is on %s %d" % [
				sd, MapGen.star_name(n), v.t, front, float(best[front][0]), q, hh.get("kind", &""), int(hh.get("body", -99))])
	v.t = t0
	m.frozen = false
	await _frames(2)


## THE WORDS HOLD AS THE SUNS TURN (ruling 23: each frame's nearest clear spot,
## `SystemOverlay._spot_off_suns`, made the words hop a whole step as a sun
## crept past a spot tried before theirs; DESIGN step 5): in the first
## TURN_RUNS close pairs, the ship in star A's close orbit at the opening zoom,
## the clock stepped TURN_STEP_S a frame through a whole lap of the pair, the
## words by the ship (CLOSE ORBIT · <system> A, or CLOSE ORBIT alone) measured
## from star A where it is (`_body_scr`, what they are centred on). Twice: as
## the overlay places them, each spot held while it stays clear
## (`SystemOverlay._spot_kept`), and placed afresh each frame, its memory
## cleared, as they were before the pair turned. Held, they hop (move more than
## 3 px in a frame, or change what they say) no more often than afresh and at
## most TURN_HOPS_MOST times a lap; never across a sun; held back off one in
## at most 1 frame in 20.
const TURN_RUNS := 3
const TURN_STEP_S := 1.5
const TURN_HOPS_MOST := 6


func _words_as_suns_turn(m: SystemMapScreen, sd: int, n: MapGen.MapNode, st: Dictionary, bad: Array[String]) -> void:
	var v = m.view
	var ov = m.overlay
	var L: SystemLayout = v.layout
	if L.pair_n <= 0.0:
		return
	var lap := TAU / L.pair_n
	var steps := int(ceil(lap / TURN_STEP_S))
	var full: String = "CLOSE ORBIT · " + String(ov.star_name_of(-1))
	var short: String = "CLOSE ORBIT"
	var t0: float = v.t
	m.frozen = true
	m.flight.place_at(-1, t0)
	await _frames(20)
	st.turn_runs += 1
	for afresh: bool in [false, true]:
		var last := Vector2.INF
		var last_s := ""
		for k in steps:
			v.t = t0 + TURN_STEP_S * float(k)
			if afresh:
				ov._spot_mem = {}
			await get_tree().process_frame
			var says := full
			var box := _said_box(ov, full)
			if box.size.x <= 0.0:
				says = short
				box = _said_box(ov, short)
			if not afresh:
				st.turn_frames += 1
				var across := _words_on_suns(ov, L, "seed %d %s, the suns turning" % [sd, MapGen.star_name(n)], bad)
				st.turn_across += int(across > 0)
				st.turn_held += int(_held(ov).has(full) or _held(ov).has(short))
			if box.size.x <= 0.0:
				last = Vector2.INF
				continue
			var rel: Vector2 = box.position - (ov._body_scr(-1) as Vector2)
			if last != Vector2.INF:
				var dd := rel.distance_to(last)
				var hop := dd > 3.0 or says != last_s
				if afresh:
					st.turn_moves_free += int(dd > 0.5 or says != last_s)
					st.turn_hops_free += int(hop)
				else:
					st.turn_moves += int(dd > 0.5 or says != last_s)
					st.turn_hops += int(hop)
			last = rel
			last_s = says
	v.t = t0
	m.frozen = false
	m.flight.place_at(-1, t0)
	await _frames(2)


## THE WORDS BY THE SHIP NEVER ACROSS A SUN, AND THE SHIP ON A SMALL WORLD'S RING
## OUTLINED, over the binaries of `RING_SEEDS` as each seed rolls them (at most
## `RING_CAP` a seed), on the real map at its opening zoom: the ship put in each
## star's close orbit and in orbit of each world, a world round one star at
## three moments of its year. Every word placed that frame
## (`SystemOverlay.label_rects`) clear of both suns' discs; the ship's own words
## (IN ORBIT · <world>, CLOSE ORBIT · <star>) counted where they stand whole,
## shortened to IN ORBIT or CLOSE ORBIT, or held back. The outline on the ring of
## each world round one star, as `_ring_outline_open`; none round both suns, nor
## (once a seed) round one sun's world. OMEGA CALLOUS REACH on seed 7, its first
## world round star A: IN ORBIT · OMEGA CALLOUS I ran across both suns, under
## the ring, above it and under the ship all crossing one (Nov 1).
## THEN IN EACH BINARY (the picks review, Nov 1): its event cards
## (`SystemPanel._events`) in name order; the ship on its first world's ring
## and each other place but a belt selected in turn, its name clear of both
## suns; and the ship let go from four sides of each world, coasting into its
## ring (held at its point, the clock still), the forecast's WILL ORBIT <world>
## or WILL BE ALONGSIDE <world> clear of both. Each name and forecast counted
## shown, held back off a sun (`SystemOverlay.label_held`) or under a higher
## label (the map's rule since before binaries). On 35ce5c73, 235 words across
## a sun: 226 forecasts (WILL ORBIT IOTA CINDER-2 I across IOTA CINDER-2 B on
## seed 7) and 9 selected names (IOTA CINDER-2 II across IOTA CINDER-2 B).
## THE SHIP'S OWN WORDS OFF THE BEACONS, at each place and each selection
## (`_ship_words_off_beacons`): clear of every event's beacon drawn that frame,
## but where the overlay says no spot cleared the suns and the beacons both
## (`SystemOverlay.label_on_beacon`, the suns-only fallback, counted and at most
## 1 in 50). On b764c344, stepped off a sun, 209 of 760 sat over a beacon (IN
## ORBIT · OMEGA CALLOUS I over the one above its world, the picks stills);
## with every system a binary (`twin=all`), CLOSE ORBIT · TAU BRINE-2 B sat on
## one where it first stood, clear of the suns. And where the overlay stepped
## them (`SystemOverlay.ship_words`), off the corner ticks of the reticle round
## the place they name and over none of the words queued under them that a spot
## clears (`_ship_words_off_beacons`). On 19fd37e5 the ticks alone moved them in
## 209 of 760 frames, and stepped they hid 8 selected names b764c344 showed
## (IOTA CINDER-2 II selected from IOTA CINDER-2 I's ring, seed 7).
func _ring_sweep() -> void:
	var seeds: Array = RING_SEEDS.duplicate()
	var cap := RING_CAP
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("ringseeds="):
			seeds = Array((a as String).substr(10).split(",")).map(func(s: String) -> int: return int(s))
		elif (a as String).begins_with("ringcap="):
			cap = int((a as String).substr(8))
	var t0 := Time.get_ticks_msec()
	var st := {"twins": 0, "places": 0, "moments": 0, "words": 0, "crossed": 0, "whole": 0, "short": 0, "held": 0,
		"rings": 0, "rim_frames": 0, "hull_frames": 0, "rim_bad": 0, "own_hid": 0, "on_disc": 0, "both": 0, "both_rim": 0, "one": 0, "one_rim": 0,
		"sel": 0, "sel_shown": 0, "sel_held": 0, "sel_under": 0, "coasts": 0, "into": 0, "fc_shown": 0, "fc_held": 0, "ev_sys": 0, "ev_moved": 0,
		"bc_words": 0, "bc_fallback": 0, "bc_crossed": 0, "sel_bc": 0, "fc_bc": 0,
		"bc_stepped": 0, "bc_ticks": 0, "bc_hid": 0, "bc_marks": 0, "sel_on_words": 0, "close": 0,
		"wide": 0, "zoom_bad": 0, "gap_n": 0, "gap_least": INF, "off": 0, "marked": 0, "marks": 0, "mark_on": 0, "untagged": 0, "look_bad": 0,
		"framed_off": 0, "near_n": 0, "near_bad": 0, "near_none": 0, "turn_runs": 0, "turn_frames": 0, "turn_hops": 0, "turn_hops_free": 0,
		"turn_moves": 0, "turn_moves_free": 0, "turn_across": 0, "turn_held": 0}
	var mark_bad: Array[String] = []
	var near_bad: Array[String] = []
	var turn_bad: Array[String] = []
	# (the binaries seen, which kept clock each opens at)
	var ti := 0
	var crossed: Array[String] = []
	var on_beacon: Array[String] = []
	var held: Array[String] = []
	var fc_held: Array[String] = []
	var sel_held: Array[String] = []
	var ev_bad: Array[String] = []
	for sd: int in seeds:
		Router.show_local()
		await _idle()
		await _frames(2)
		Rng.forced = sd
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var m: SystemMapScreen = null
		# (spread over the map: every so many of the seed's binaries, the ones it
		# must see and the first one-sun system with a world)
		var twins: Array = []
		for raw in Run.map:
			var c: MapGen.MapNode = raw
			if c.twin and MapGen.twin_ok(c):
				twins.append(c)
		var pick: Array = []
		for i in mini(cap, twins.size()):
			pick.append(twins[int(float(i) * float(twins.size()) / float(mini(cap, twins.size())))])
		for ni: int in RING_MUST.get(sd, []):
			if ni < Run.map.size() and not pick.has(Run.map[ni]) and (Run.map[ni] as MapGen.MapNode).twin:
				pick.append(Run.map[ni])
		for raw in Run.map:
			var c: MapGen.MapNode = raw
			if not (c.twin and MapGen.twin_ok(c)) and c.type == MapGen.NodeType.SYSTEM and c.region != MapGen.Region.FAUNA and c.index != Run.at:
				pick.append(c)
				break
		for raw in pick:
			var n: MapGen.MapNode = raw
			var two := n.twin and MapGen.twin_ok(n)
			var Ln := SystemLayout.of(n)
			ti += int(two)
			var w0 := -1
			for b in Ln.bodies:
				if b.world != &"" and w0 < 0:
					w0 = b.index
			# (in a binary, a world round one sun when it has one: the ship put
			# back round a giant out past the pair widens the opening to show it,
			# and a wide pair's opening is checked framed on its own part. Seed
			# 4242's ETA GRIST SECUNDUS, a twin since stations were halved on
			# Nov 3, opened at 0.32 round its giant, 1.33 of its whole system)
			if two:
				for b in Ln.bodies:
					if b.world != &"" and SystemLayout.is_star(b.host_id):
						w0 = b.index
						break
			if w0 < 0:
				continue
			Run.at = n.index
			n.visited = true
			SystemMapScreen._parked[n.index] = {"at": w0, "mode": &"rail"}
			# OPENED AT A KEPT CLOCK (ruling 23): each binary at the next of
			# LAP_CLOCKS points round its pair's lap, so the opening framing and
			# everything below meet the pair at every angle (all at t 0 held still)
			var lap: float = TAU / Ln.pair_n if two and Ln.pair_n > 0.0 else 0.0
			Run.map_clock[n.index] = lap * float(ti % LAP_CLOCKS) / float(LAP_CLOCKS)
			if m == null or not is_instance_valid(m) or Router.current != m:
				m = await _map()
			else:
				# (one map shown again for another system, where the game makes a new
				# one each time: the overlay's ring easing, fade and trail, which name
				# the last system's bodies by index, start afresh as on a new map)
				await m.show_system(n, Run.map_t(n.index), false)
				m.overlay._ok_body = -9
				m.overlay._was = -9
				m.overlay._left = {}
				m.overlay._pulse = {}
				m.overlay._ok = 1.0
				m.overlay._ok_v = 0.0
				m.overlay._trail = []
				await _frames(2)
			if m == null or m.view.node != n:
				h._fail("seed %d: no map at %s" % [sd, MapGen.star_name(n)])
				continue
			var L: SystemLayout = m.view.layout
			var ov = m.overlay
			if not two:
				# ONE SUN, once a seed: a world's ring is never outlined
				m.flight.place_at(w0, m.view.t)
				var r1 := await _ring_frames(m, w0, 6, 2)
				st.one += 1
				st.one_rim += int(r1.rim_px) + int(r1.ringed)
				continue
			st.twins += 1
			st.close += int(L.close)
			if not L.close:
				_pair_marks(m, sd, n, st, mark_bad)
			else:
				await _nearer_hit(m, sd, n, st, near_bad)
				if st.turn_runs < TURN_RUNS:
					await _words_as_suns_turn(m, sd, n, st, turn_bad)
			var places: Array[int] = L.stars()
			for b in L.bodies:
				if b.world != &"":
					places.append(b.index)
			for p: int in places:
				var round_one := p >= 0 and SystemLayout.is_star(L.bodies[p].host_id)
				st.places += 1
				for j in (3 if round_one else 1):
					# (and the pair at the next of LAP_CLOCKS angles each moment: the
					# words keep off suns that stand anywhere round their lap)
					var tt: float = 37.0 + lap * float((ti + st.moments) % LAP_CLOCKS) / float(LAP_CLOCKS) 						+ (L.bodies[p].period * float(j) / 3.0 if p >= 0 else 0.0)
					m.view.t = tt
					m.flight.place_at(p, tt)
					var r := await _ring_frames(m, p, 2, 2)
					st.moments += 1
					# EVERY WORD PLACED, clear of both suns
					st.words += (ov.label_rects as Array).size()
					st.crossed += _words_on_suns(ov, L, "seed %d %s, the ship at %s" % [sd, MapGen.star_name(n), ov._place_nm(p)], crossed)
					# THE SHIP'S OWN WORDS: whole, shortened or held back
					var full: String = ("CLOSE ORBIT · " if p < 0 else "IN ORBIT · ") + String(ov._place_nm(p))
					var says: Array = ov.label_says
					if says.has(full):
						st.whole += 1
					elif says.has(full.get_slice(" · ", 0)):
						st.short += 1
					else:
						st.held += 1
						held.append("seed %d %s at %s (%s)" % [sd, MapGen.star_name(n), ov._place_nm(p), ", ".join(PackedStringArray(says))])
					# and clear of every beacon drawn that frame
					_ship_words_off_beacons(ov, full, p, "seed %d %s, the ship at %s" % [sd, MapGen.star_name(n), ov._place_nm(p)], st, on_beacon)
					# THE OUTLINE: on a world round one star, none round both
					if p < 0:
						continue
					if round_one:
						st.rings += 1
						st.hull_frames += int(r.hull)
						st.rim_frames += int(r.rim)
						st.rim_bad += int(r.colour) + int(r.on_hull) + int(r.apart) + (int(r.seen) - int(r.ringed))
						st.own_hid += int(r.own_hid)
						st.on_disc += int(r.on_disc)
					else:
						st.both += 1
						st.both_rim += int(r.rim_px) + int(r.ringed)
				# AND WHEELED OUT TO THE WHOLE SYSTEM, a wide pair's world round one
				# sun: where the ship sits on its world's disc (framed on the pair
				# as it opens since "gap:A", it rides clear of it)
				if round_one and not L.close:
					m.view.t = 37.0
					m.flight.place_at(p, 37.0)
					m._zoom_to = m.zoom_min
					m.view.zoom = m.zoom_min
					m.view.pan = Vector2.ZERO
					var rw := await _ring_frames(m, p, 2, 2)
					st.rings += 1
					st.hull_frames += int(rw.hull)
					st.rim_frames += int(rw.rim)
					st.rim_bad += int(rw.colour) + int(rw.on_hull) + int(rw.apart) + (int(rw.seen) - int(rw.ringed))
					st.own_hid += int(rw.own_hid)
					st.on_disc += int(rw.on_disc)
					m._zoom_to = m.open_zoom
					m.view.zoom = m.open_zoom
					m.view.pan = -m.home_at * m.open_zoom
			# THE EVENT CARDS IN NAME ORDER, as the SATELLITES list under them
			# (`SystemPanel._events`, what < and > step): a body's after the one
			# named before it, the star's last
			var rank := {}
			var ord := L.name_order()
			for k in ord.size():
				rank[ord[k]] = k
			var last := -1
			var made := -1
			var in_order := true
			var as_made := true
			var star_seen := false
			var ev_names := PackedStringArray()
			for pair: Array in m.panel._events():
				var bi: int = pair[0]
				if bi < 0:
					star_seen = true
					continue
				ev_names.append(L.bodies[bi].name)
				if star_seen or int(rank[bi]) < last:
					in_order = false
				if bi < made:
					as_made = false
				last = int(rank[bi])
				made = bi
			st.ev_sys += 1
			st.ev_moved += int(not as_made)
			if not in_order:
				ev_bad.append("seed %d %s: %s" % [sd, MapGen.star_name(n), ", ".join(ev_names)])
			# EACH OTHER PLACE SELECTED, the ship on the first world's ring: its
			# name beside its reticle, never across a sun; at three moments of the
			# year of the first world round one sun (a world close to its sun
			# meets it with its name only part of the way round)
			var sel_at: Array[int] = L.stars()
			var wr := -1
			for b in L.bodies:
				if b.kind != &"belt" and b.index != w0:
					sel_at.append(b.index)
				if wr < 0 and b.world != &"" and SystemLayout.is_star(b.host_id):
					wr = b.index
			for j in 3:
				var ts: float = 37.0 + lap * float((ti + j * 3 + 1) % LAP_CLOCKS) / float(LAP_CLOCKS) 					+ (L.bodies[wr].period * float(j) / 3.0 if wr >= 0 else float(j) * 20.0)
				m.view.t = ts
				m.flight.place_at(w0, ts)
				await _frames(2)
				for q: int in sel_at:
					ov.selected = q
					await _frames(2)
					var nm_q: String = ov.star_name_of(q) if SystemLayout.is_star(q) else L.bodies[q].name
					st.sel += 1
					if (ov.label_says as Array).has(nm_q):
						st.sel_shown += 1
					elif _held(ov).has(nm_q):
						st.sel_held += 1
						sel_held.append("seed %d %s: %s held back" % [sd, MapGen.star_name(n), nm_q])
					else:
						st.sel_under += 1
						st.sel_on_words += int(_under_ship_words(ov, nm_q, "IN ORBIT · " + String(ov._place_nm(w0))))
					st.words += (ov.label_rects as Array).size()
					st.crossed += _words_on_suns(ov, L, "seed %d %s, %s selected" % [sd, MapGen.star_name(n), nm_q], crossed)
					_ship_words_off_beacons(ov, "IN ORBIT · " + String(ov._place_nm(w0)), w0, "seed %d %s, %s selected" % [sd, MapGen.star_name(n), nm_q], st, on_beacon)
					_said_on_beacon(ov, nm_q, st, "sel_bc")
				ov.selected = -2
			# LET GO AND COASTING INTO EACH WORLD'S RING (`restore_free`, held at
			# its point, the clock still): the forecast's WILL ORBIT <world> or
			# WILL BE ALONGSIDE <world> by the ring it will take, never across a
			# sun, from four sides
			m.frozen = true
			for b in L.bodies:
				if b.world == &"":
					continue
				var w: int = b.index
				var nm_w: String = ov._place_nm(w)
				var c3: Vector3 = m.flight.center(w, m.view.t)
				var cv3: Vector3 = m.flight.center_vel(w, m.view.t)
				var rt: float = m.flight.orbit_r(w)
				for k in 4:
					var dir := Vector2.from_angle(TAU * float(k) / 4.0 + 0.4)
					var at := Vector2(c3.x, c3.z) + dir * rt * 1.4
					var v := Vector2(cv3.x, cv3.z) - dir * 6.0
					m.flight.restore_free(m.view.t, at, v, atan2(v.y * 0.38, v.x))
					for f in 3:
						await get_tree().process_frame
						m.flight.f.p = at
						m.flight.f.v = v
					st.coasts += 1
					var out: Dictionary = (m.flight.line as Dictionary).get("out", {})
					if out.is_empty() or int(out.get("body", -99)) != w:
						continue
					st.into += 1
					var says_w: Array = ov.label_says
					var held_w: Array = _held(ov)
					if says_w.has("WILL ORBIT " + nm_w) or says_w.has("WILL BE ALONGSIDE " + nm_w):
						st.fc_shown += 1
					elif held_w.has("WILL ORBIT " + nm_w) or held_w.has("WILL BE ALONGSIDE " + nm_w):
						st.fc_held += 1
						fc_held.append("seed %d %s into %s, held back (%s)" % [sd, MapGen.star_name(n), nm_w, ", ".join(PackedStringArray(says_w))])
					else:
						fc_held.append("seed %d %s into %s, under a higher label (%s)" % [sd, MapGen.star_name(n), nm_w, ", ".join(PackedStringArray(says_w))])
					st.words += says_w.size()
					st.crossed += _words_on_suns(ov, L, "seed %d %s, coasting into %s" % [sd, MapGen.star_name(n), nm_w], crossed)
					_said_on_beacon(ov, "WILL ORBIT " + nm_w, st, "fc_bc")
					_said_on_beacon(ov, "WILL BE ALONGSIDE " + nm_w, st, "fc_bc")
			m.frozen = false
			m.flight.place_at(w0, m.view.t)
			await _frames(2)
	print("  --   the ring sweep: %d binaries (%d close pairs) over seeds %s in %.1f s; the ship at %d places, %d moments; %d words placed; its own words whole %d, shortened %d, held back %d" % [
		st.twins, st.close, seeds, float(Time.get_ticks_msec() - t0) / 1000.0, st.places, st.moments, st.words, st.whole, st.short, st.held])
	print("  --   and %d places selected (%d names shown, %d held back off a sun, %d under a higher label), %d coasts let go (%d into the ring aimed at, its forecast shown in %d, held back off a sun in %d)" % [
		st.sel, st.sel_shown, st.sel_held, st.sel_under, st.coasts, st.into, st.fc_shown, st.fc_held])
	if not crossed.is_empty():
		var by := {"the ship at": 0, "selected:": 0, "coasting into": 0}
		for e: String in crossed:
			for k: String in by:
				if e.contains(k):
					by[k] = int(by[k]) + 1
		print("  --   words across a sun: %d with the ship at a place, %d of a selected place, %d coasting into a ring" % [by["the ship at"], by["selected:"], by["coasting into"]])
	for e: String in held.slice(0, 6):
		print("  --     held back: %s" % e)
	for e: String in sel_held.slice(0, 6):
		print("  --     selected name %s" % e)
	for e: String in fc_held.slice(0, 6):
		print("  --     forecast not shown: %s" % e)
	print("  --   the words by the ship: %d placed, %d over an event's beacon drawn that frame, %d left by one where no spot cleared the suns and the beacons both (the suns-only fallback); over a beacon too, %d selected names and %d forecasts (counted, not judged: a first spot that meets no sun is kept, as with one sun)" % [
		st.bc_words, st.bc_crossed, st.bc_fallback, st.sel_bc, st.fc_bc])
	print("  --   stepped clear of the beacons %d times: %d on the reticle's ticks round their place, %d over words they hid, %d hiding words where no spot cleared them too; %d selected names under the ship's own words (counted, not judged: where both first stand, as with one sun)" % [
		st.bc_stepped, st.bc_ticks, st.bc_hid, st.bc_marks, st.sel_on_words])
	for e: String in on_beacon.slice(0, 6):
		print("  --     not clear: %s" % e)
	_saw("ring sweep: binaries", st.twins)
	_saw("ring sweep: moments", st.moments)
	_saw("ring sweep: places selected", st.sel)
	_saw("ring sweep: coasts into a ring", st.into)
	h._ok("no word on the map is written across a sun in %d binaries (%d close pairs) of %d seeds: the ship at each place, each other place selected, coasting into each ring (%d words at %d moments, %d selections and %d coasts, %d across)%s" % [
		st.twins, st.close, seeds.size(), st.words, st.moments, st.sel, st.coasts, st.crossed,
		"" if crossed.is_empty() else ": " + "; ".join(crossed.slice(0, 4))],
		st.crossed == 0 and st.twins >= seeds.size() * mini(cap, 8) and st.close > 0 and st.words > st.moments and st.sel > st.twins and st.into > st.twins)
	# A WIDE PAIR FRAMED ON ITS OWN PART, and what that leaves off the picture marked
	print("  --   wide pairs opened: %d; their worlds round one sun at least %.1f px clear of their suns' discs (%d); %d beacons off the picture, %d marked, %d arrows (%d on something drawn)" % [
		st.wide, st.gap_least, st.gap_n, st.off, st.marked, st.marks, st.mark_on])
	for e: String in mark_bad.slice(0, 6):
		print("  --     %s" % e)
	_saw("ring sweep: wide pairs opened", st.wide)
	_saw("ring sweep: beacons off the picture", st.off)
	h._ok("every wide pair opens framed on its own part (`open_view`), nearer than the whole system and centred on it (%d of %d not)" % [st.zoom_bad, st.wide],
		st.wide > 0 and st.zoom_bad == 0)
	h._ok("and opened at kept clocks round the pair's lap (%d angles), the pair as it stands then all on the picture (%d of %d not)" % [LAP_CLOCKS, st.framed_off, st.wide],
		st.wide > 0 and st.framed_off == 0)
	# THE NEARER SUN TAKES THE CLICK, in each close pair standing one sun in front
	# of the other (`_nearer_hit`)
	for e: String in near_bad.slice(0, 6):
		print("  --     %s" % e)
	_saw("ring sweep: clicks where the suns overlap", st.near_n)
	h._ok("in each close pair, where the suns' discs overlap as the pair turns, a click there is on the nearer sun, the one drawn on top (%d clicks, %d not; %d pairs never overlapping)" % [
		st.near_n, st.near_bad, st.near_none], (st.near_n > 0 or SystemLayout.pair_speed() == 0.0) and st.near_bad == 0)
	# THE WORDS HOLD AS THE SUNS TURN (`_words_as_suns_turn`)
	for e: String in turn_bad.slice(0, 6):
		print("  --     %s" % e)
	print("  --   the suns turning a lap under the words by the ship, %d close pairs, %d frames: held where they stood, %d moves and %d hops over 3 px; each frame placed afresh, %d moves and %d hops; %d across a sun, %d held back" % [
		st.turn_runs, st.turn_frames, st.turn_moves, st.turn_hops, st.turn_moves_free, st.turn_hops_free, st.turn_across, st.turn_held])
	_saw("ring sweep: frames of the suns turning under the words", st.turn_frames)
	h._ok("a lap of a close pair turning under the words by the ship in star A's close orbit: never across a sun, held where they stood while clear (%d hops over 3 px a lap, %d placed afresh each frame; %d across, %d held back of %d frames)" % [
		st.turn_hops, st.turn_hops_free, st.turn_across, st.turn_held, st.turn_frames],
		(st.turn_runs > 0 or SystemLayout.pair_speed() == 0.0) and st.turn_across == 0 and st.turn_hops <= st.turn_hops_free
		and st.turn_hops <= TURN_HOPS_MOST * st.turn_runs and st.turn_held * 20 <= st.turn_frames)
	h._ok("and draws each world round one sun at least %.0f px clear of its sun's disc beside it (least %.1f px over %d; fitted to the whole system it was 5)" % [PAIR_GAP_LEAST, st.gap_least, st.gap_n],
		st.gap_n >= 2 * st.wide and st.gap_least >= PAIR_GAP_LEAST)
	h._ok("every event's beacon off the picture as it opens has an arrow at the frame's edge (%d of %d), each inside the frame and on nothing drawn there (%d on something)" % [
		st.marked, st.off, st.mark_on], st.off > 0 and st.marked == st.off and st.mark_on == 0)
	h._ok("and each event's arrow carries the event's key glyph, a ship's none (%d of %d arrows not)" % [st.untagged, st.marks],
		st.marks > 0 and st.untagged == 0)
	h._ok("and as drawn there, each side arrow's glyph as tall as the arrow and every arrow hollow (%d of %d arrows not)" % [st.look_bad, st.marks],
		st.marks > 0 and st.look_bad == 0)
	h._ok("the words by the ship stand whole or shortened at nearly every place (%d whole, %d shortened, %d held back of %d)" % [st.whole, st.short, st.held, st.moments],
		st.held * 50 <= st.moments)
	h._ok("and never over an event's beacon drawn that frame, but where no spot clears the suns and the beacons both (%d placed, %d over a beacon, %d by one for want of a spot)%s" % [
		st.bc_words, st.bc_crossed, st.bc_fallback, "" if on_beacon.is_empty() else ": " + "; ".join(on_beacon.slice(0, 4))],
		st.bc_crossed == 0 and st.bc_words > st.moments and st.bc_fallback * 50 <= st.bc_words)
	h._ok("and where stepped, clear of the reticle's ticks round the place they name and of the words queued under them (%d stepped, %d on a tick, %d over words they hid; %d over words for want of a spot, with the fallback at most 1 in 50)" % [
		st.bc_stepped, st.bc_ticks, st.bc_hid, st.bc_marks],
		st.bc_stepped > 0 and st.bc_ticks == 0 and st.bc_hid == 0 and (st.bc_fallback + st.bc_marks) * 50 <= st.bc_words)
	h._ok("a selected place's name is held back off a sun at nearly no selection (%d of %d; %d shown, %d under a higher label as ever), and the forecast's words at nearly no coast into a ring (%d of %d; %d shown)" % [
		st.sel_held, st.sel, st.sel_shown, st.sel_under, st.fc_held, st.into, st.fc_shown],
		st.sel_held * 20 <= st.sel and st.fc_held * 20 <= st.into and st.sel_shown * 4 >= st.sel * 3 and st.fc_shown * 4 >= st.into * 3)
	h._ok("every binary's event cards go in name order, as its SATELLITES list (%d binaries, %d of them with cards out of the order the bodies were made)%s" % [
		st.ev_sys, st.ev_moved, "" if ev_bad.is_empty() else ": " + "; ".join(ev_bad.slice(0, 4))], ev_bad.is_empty() and st.ev_sys == st.twins and st.ev_moved > 0)
	h._ok("on every ring of a world round one sun of a binary the ship is outlined in light: %d rings, %d of %d frames with the hull drawn outlined, %d outline pixels wrong, %d hull pixels hidden by its own world (%d frames with the hull over that world's disc)" % [
		st.rings, st.rim_frames, st.hull_frames, st.rim_bad, st.own_hid, st.on_disc],
		st.rings > 2 * st.twins and st.hull_frames > 0 and st.rim_frames == st.hull_frames and st.rim_bad == 0 and st.own_hid == 0 and st.on_disc > 0)
	h._ok("and never on a ring round both suns (%d rings, %d outline pixels or outlined frames) nor round one sun (%d systems, %d)" % [st.both, st.both_rim, st.one, st.one_rim],
		st.both > 0 and st.both_rim == 0 and st.one > 0 and st.one_rim == 0)
