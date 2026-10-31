extends Node

## STAR B IS A PLACE, AS THE ONE STAR IS (ruling 20, Oct 30: "Prototype: twin:A
## giant:A"), on the real map, headless:
##   godot --headless --fixed-fps 60 --path . -- sheet=TwinSiteTest
##
## A system with two suns (the run's ordinary system with the longest name, made
## a twin the way a harness may, `n.twin = true`), from a world round star A:
##   - star B is hit where it is drawn, at its own size, and star A where it is;
##     the tip names each "<system> A" / "<system> B" with its kind;
##   - one click on star B selects it: the panel's sector page shows both suns,
##     each with its own facts and FLY HERE, and the system reads TWO SUNS; every
##     word and button on it inside the panel and none on another (fit means
##     nothing overlaps), here and on the giant's page with its MASS line;
##   - a right-click zooms onto star B and holds it in the middle;
##   - star B's FLY HERE flies there: the status line says where it is going,
##     then CLOSE ORBIT · <system> B; its FLY HERE reads IN A CLOSE ORBIT;
##   - the map leaves the ship at star B (`Run.site_here` -4), LOCAL finds no
##     event there (star B holds none), and the map puts it back there;
##   - a partner in star B's close orbit is drawn where it said it was (a spot
##     at -4 is absolute, as at -1), and hidden behind star B's disc there;
##   - a ship left at star B in a system with one sun comes back at the star;
##   - the zoom the map opens at is the layout's own formula
##     (`SystemLayout.open_zoom`) on its frame, and on the real frame every
##     twin opens at or nearer than the zoom its rings were fitted to;
##   - every giant's MASS line is 1/n of its star (n the whole number nearest
##     1 / gm_frac), "OF ITS STARS" round two suns;
##   - the HUD's SECTOR tab says "two suns".
## Prints how many twin systems and cases each part saw.

const PanelS := preload("res://scripts/ui/sysmap/SystemPanel.gd")

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
	h.seed_run(4242)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_fit_zooms()
	_mass_lines()
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
	h._ok("the ship is put back in orbit of the world round star A (%d)" % m.flight.reached(), m.flight.reached() == wa)
	_saw("twin systems")
	await _stars_as_places(m, n)
	await _fly_to_b(m, n)
	await _back_at_b(n)
	await _partner_at_b(n)
	await _giant_page(n)
	await _one_sun_fallback(n)
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


## The ordinary system that may have two suns whose "<name> B" is widest.
func _longest_twin() -> MapGen.MapNode:
	var font := UITheme.pixel_font()
	var best: MapGen.MapNode = null
	var best_w := -1.0
	for raw in Run.map:
		var c: MapGen.MapNode = raw
		if not MapGen.twin_ok(c) or c.region == MapGen.Region.FAUNA or c.index == Run.at:
			continue
		var w := font.get_string_size(MapGen.star_name(c) + " B", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_HEAD).x
		if w > best_w:
			best_w = w
			best = c
	if best != null:
		print("  --   the longest name of a system that may have two suns: %s (%d px at the panel's head size)" % [MapGen.star_name(best), int(best_w)])
	return best


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
	h._ok("this map opened at %.4f, at or nearer than its rings were fitted to (%.4f; the edge alone on the layout's frame %.4f, on this one %.4f)" % [
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
	# THE HIT, at each star's drawn place and size
	var sb: Vector2 = ov.star_scr(B)
	var want_b: Vector2 = m.view.block_round(m.view.screen(L.star2_at.x, L.star2_at.y))
	h._ok("star B is drawn where it holds still (%s, the plane's %s)" % [sb, want_b], sb == want_b)
	var hb: Dictionary = ov.hit(sb)
	h._ok("a click on star B is on star B (%s %d)" % [hb.get("kind", &""), int(hb.get("body", -99))], hb.get("kind", &"") == &"star" and int(hb.get("body", -99)) == B)
	var rim: float = ov.star_disc(B)
	var he: Dictionary = ov.hit(sb + Vector2(maxf(8.0, rim) - 1.0, 0.0))
	h._ok("and at its drawn edge (%.1f px out)" % (maxf(8.0, rim) - 1.0), int(he.get("body", -99)) == B or he.get("kind", &"") == &"body")
	var ha: Dictionary = ov.hit(m.view.origin())
	h._ok("a click on star A is on star A (%d)" % int(ha.get("body", -99)), ha.get("kind", &"") == &"star" and int(ha.get("body", -99)) == -1)
	_saw("hits", 3)
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
	h._ok("the panel says TWO SUNS, and names %s and %s" % [nm_a, nm_b], words.has("TWO SUNS") and words.has(nm_a) and words.has(nm_b))
	h._ok("its picture holds both suns", m.panel._box.find_child("TwoSuns", true, false) != null
		and m.panel._box.find_child("TwoSuns", true, false).get_child_count() == 2)
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
	var want_r: Vector2 = Vector2(L.star2_at.x, L.star2_at.y * m.view.TILT) * m.view.zoom
	h._ok("star B's place on screen, from the star (%s)" % pr, pr.distance_to(want_r) < 0.01)
	m.right_click(hb)
	var held := false
	for i in 3000:
		await get_tree().process_frame
		if m._focus_body == B and m._glide.is_empty():
			held = true
			break
	var look: Vector2 = m._look_at()
	var mid := Vector2(L.star2_at.x, L.star2_at.y * m.view.TILT)
	h._ok("a right-click on star B zooms onto it and holds it in the middle (%s, want %s)" % [look, mid], held and look.distance_to(mid) < 1.0)
	m.right_click({})
	for i in 3000:
		await get_tree().process_frame
		if m._glide.is_empty() and m._focus_body == -9:
			break
	await _frames(4)
	h._ok("and a second one back out to the whole sector (zoom %.3f of %.3f)" % [m.view.zoom, m.zoom_min], absf(m.view.zoom - m.zoom_min) < 0.002)
	# THE PARTNERS' AND YOUR SHIP'S DISC TEST: behind star B (further from the
	# viewer, on its disc) is hidden by it; in front is not
	var behind: Array = ov._star_occ(L.star2_at + Vector2(0.0, -2.0))
	var front: Array = ov._star_occ(L.star2_at + Vector2(0.0, 2.0))
	h._ok("a ship just behind star B is hidden by its disc, one just in front is not",
		behind.any(func(o: Array) -> bool: return o[0] == sb) and not front.any(func(o: Array) -> bool: return o[0] == sb))
	_saw("star B places", 1)


## THE ROW `_way_there` built for place i, and its button.
func _way_button(m: SystemMapScreen, i: int) -> Button:
	var row: Node = m.panel._box.find_child(PanelS.way_name(i), true, false)
	if row == null:
		return null
	for c in row.get_children():
		if c is Button:
			return c
	return null


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
	# adds), each no wider than the text column; the event cards under them
	# are measured and printed, not judged here (they are the list's, from
	# before two suns: a card naming the world you orbit runs past it, below)
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
	if card_w > PanelS.TEXT_W + 0.5:
		print("  --   %s: an event card asks for %.0f px of the %d (%s): the list's, not judged here" % [tag, card_w, PanelS.TEXT_W, card_said])
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
	# where the ship is: round star B, judged once the flight knows star B's
	# centre (`ShipFlight.center`, the flight build's)
	var c3: Vector3 = m.flight.center(B, m.view.t)
	var p3: Vector3 = m.flight.where3()
	var d := Vector2(p3.x, p3.z).distance_to(m.view.layout.star2_at)
	if Vector2(c3.x, c3.z).distance_to(m.view.layout.star2_at) < 0.5:
		h._ok("round star B, %.1f px from it (its close orbit %.1f)" % [d, m.flight.orbit_r(B)], absf(d - float(m.flight.orbit_r(B))) < 3.0)
	else:
		print("  --   round star B not judged: ShipFlight.center(STAR_B) is %s, not star B's place (the flight's change)" % c3)
	var fb2 := _way_button(m, B)
	var fa2 := _way_button(m, -1)
	h._ok("star B's FLY HERE reads IN A CLOSE ORBIT, greyed (%s); star A's FLY HERE (%s)" % [fb2.text if fb2 != null else "none", fa2.text if fa2 != null else "none"],
		fb2 != null and fb2.text == "IN A CLOSE ORBIT" and fb2.disabled and fa2 != null and fa2.text == "FLY HERE")
	await _fit(m, "the sector page, in star B's close orbit")
	h._ok("the ship's place as LOCAL is told it is star B (%d)" % m.ship_place(), m.ship_place() == B)
	# THE HUD's SECTOR tab says two suns
	Router.hud.refresh()
	var tip := String(Router.hud._tab_system.tooltip_text).replace("\n", " ")
	h._ok("the SECTOR tab says two suns (%s)" % tip.strip_edges(), tip.contains("two suns"))
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
	_saw("returns to star B")


## A PARTNER IN STAR B'S CLOSE ORBIT, as the wire brings it: drawn where it
## said, absolute (star B holds still); a partner off a world, off that world.
func _partner_at_b(n: MapGen.MapNode) -> void:
	var m := Router.current as SystemMapScreen
	if m == null:
		h._fail("no map for the partner")
		return
	var B := SystemLayout.STAR_B
	var L: SystemLayout = m.view.layout
	var at := L.star2_at + Vector2(L.star_rail_of(B), 0.0)
	var w := 0
	for b in L.bodies:
		if b.world != &"":
			w = b.index
			break
	var ids := [70001, 70002]
	Net.roster[ids[0]] = {"id": ids[0], "at": n.index, "order": 90, "name": "Mercer"}
	Net.roster[ids[1]] = {"id": ids[1], "at": n.index, "order": 91, "name": "Kevin"}
	Net.spots[ids[0]] = {"at": n.index, "body": B, "x": at.x, "z": at.y, "ang": 0.5}
	Net.spots[ids[1]] = {"at": n.index, "body": w, "x": 6.0, "z": -2.0, "ang": 0.0}
	var got := {}
	for e: Array in m.partner_points():
		got[int(e[0])] = e[1]
	var c3: Vector3 = m.flight.center(w, m.view.t)
	h._ok("a partner in star B's close orbit is drawn where it said (%s, sent %s)" % [got.get(ids[0], "none"), at],
		got.has(ids[0]) and (got[ids[0]] as Vector2).distance_to(at) < 0.01)
	h._ok("and one off a world, off that world as it is here", got.has(ids[1])
		and (got[ids[1]] as Vector2).distance_to(Vector2(c3.x, c3.z) + Vector2(6.0, -2.0)) < 0.01)
	for id in ids:
		Net.roster.erase(id)
		Net.spots.erase(id)
	_saw("partners at star B")


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
	Run.at = one.index
	SystemMapScreen._parked[one.index] = {"at": SystemLayout.STAR_B, "mode": &"rail"}
	h._ok("its place reads as the star (%d)" % Run.site_here(one), Run.site_here(one) == -1)
	var m := await _map()
	h._ok("and the map puts the ship in the star's close orbit (%d)" % (m.flight.reached() if m != null else -99), m != null and m.flight.reached() == -1)


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
