extends Node

## THE DERELICT HAULER SAYS WHAT YOU ARE CLAIMING, AND CLAIMING IT NEVER COSTS
## YOU THE STRIP:
##   godot --headless --fixed-fps 60 --path . -- sheet=DerelictTest [seed N]
##
## Jeremy, friends' alpha: he flew a heavy ship, took "Claim the hull", got a
## light frame he did not want, and had given up "Strip it for scrap" for it.
## The frame was rolled off the loot stream after the choice, so nothing could
## name it first, and LEAVE IT was the only way to say no.
##
## Everything here is read off what is drawn and what the run holds, never off
## the new helpers, so the same sheet runs against the old code and fails there:
##  1. On the real LOCAL, the derelict's page at three systems whose frame is
##     light, medium and heavy, in all three layouts: the claim's card names the
##     frame's weight and no other, and the page passes the box test at 960x540
##     (the band on screen and off the HUD, every card inside it and off the
##     others and the text, its words inside it). YOU CHOSE names it too, and the
##     hull found is that weight.
##  2. The same frame on every visit, and for a partner: claimed again with the
##     loot stream moved and another seat, it is the same hull, number for number.
##  3. Declining it pays the strip. The strip's credits and crate measured, then
##     the claim's frame cut up with the rail's SCRAP (where LEAVE IT was, inside
##     the rail, off TRANSFER, no wider than LEAVE IT left it) for the same credits
##     and the same crate, once. SCRAP survives a backed-out TRANSFER and a save
##     and load, and the system map's hull row has it too. A wreck's hull, which
##     cost you nothing, keeps LEAVE IT.
##  4. A frame still on offer is paid, never lost. Claiming a second derelict
##     put the new frame over it, and buying a yard hull threw it away, its pay
##     with it both times. Now each pays the strip's credits and crate first,
##     and the log names the crate and says it is in SECTOR LOOT (Jon: a crate
##     landing there with nothing on screen was "super NOT intuitive"). Backing
##     out of the yard hull does not bring the paid frame back to pay twice.
##  5. SCRAP at three digits (danger 5 or 6 pays 105): the box test on the rail
##     and on the system map's row, its words inside the button.
##  6. A 0.4.2-alpha.1 save (VERSION 36) holding a found hull loads it with
##     LEAVE IT and no SCRAP, as that build had it.

const ID := &"derelict_hauler"
const VIEW := Rect2(0, 0, 960, 540)
const WEIGHTS: Array[String] = ["light", "medium", "heavy"]

var h := Harness.new()
var _tree: SceneTree
## Every log line since the last clear, as the log panel is handed them.
var _said: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _frames(k: int) -> void:
	for i in k:
		await _tree.process_frame


func _run() -> void:
	_tree = get_tree()
	await _frames(2)
	LocalEventDrawer.quiet = true
	Router.animate_in_harness = false
	h.seed_run(4242)
	Run.start_new_run(&"korvan", int(HullData.Weight.HEAVY))
	var at: Dictionary = await _systems_by_weight()
	print("-- the card names the frame")
	for w in WEIGHTS:
		if h._ok("a system whose derelict frame is %s" % w, at.has(w)):
			await _names_the_frame(at[w], w)
	print("-- the same frame whatever else was rolled")
	if not at.is_empty():
		await _same_frame(at.values()[0])
	print("-- declining it pays the strip")
	if not at.is_empty():
		await _pays_the_strip(at.values()[0])
	Sig.log_line.connect(func(text: String, _kind: StringName) -> void: _said.append(text))
	print("-- a frame still on offer is paid, never lost")
	if h._ok("two systems with a derelict", at.size() >= 2):
		await _second_claim(_live(at.values()[0]), _live(at.values()[1]))
		await _yard_hull(_live(at.values()[0]))
	print("-- SCRAP at three digits fits")
	await _three_digits()
	print("-- a 0.4.2-alpha.1 save's frame keeps LEAVE IT")
	if not at.is_empty():
		await _old_save(_live(at.values()[0]))
	LocalEventDrawer.quiet = false
	LocalEventDrawer.layout = &"column"
	print("")
	h.verdict("derelicttest")
	_tree.quit(1 if h._fails > 0 else 0)


# ------------------------------------------------------------------- helpers

## The system holding the derelict alone, untouched, the ship at it, whole.
## `keep_hull` flies there with the hull on offer still on offer.
func _fresh(n: MapGen.MapNode, keep_hull := false) -> void:
	n.options.clear()
	n.options.append(ID)
	n.taken.clear()
	n.results.clear()
	n.left.clear()
	n.said.clear()
	n.jetsam.clear()
	n.cleared = false
	n.ambush_pending = false
	Run.at = n.index
	Run.dead = false
	if not keep_hull:
		Run.found_hull = null
	Run.hp = Run.max_hp()
	Run.heat = 0
	Run.credits = 180


## The map's own node at `n`'s index. A load (section 3 saves and loads) builds
## Run.map anew, so a node held from before it is a copy the run no longer
## reads: the page opens the live one, and `_fresh` on the old one resets nothing.
func _live(n: MapGen.MapNode) -> MapGen.MapNode:
	return Run.map[n.index]


## A hull, number for number.
func _sig(x: HullData) -> String:
	if x == null:
		return "none"
	return "%s %s w%d hull %d heat %d/%d r%d %s %s" % [x.name, x.tier_letter(), x.weight,
		x.max_hull, x.heat_cap, x.dissipation, x.reactor, x.perk_id, str(x.tier_perks)]


func _weight(x: HullData) -> String:
	return HullData.weight_name(x.weight).to_lower() if x != null else "none"


## Whether these words name weight `w` and no other.
func _names(words: String, w: String) -> bool:
	var up := " %s " % words.to_upper().replace("(", " ").replace(")", " ")
	for o in WEIGHTS:
		if up.contains(" %s " % o.to_upper()) != (o == w):
			return false
	return true


## One ordinary system in the derelict's band per frame weight, found by
## claiming it: the frame the claim hands over.
func _systems_by_weight() -> Dictionary:
	var out := {}
	var band: Dictionary = OptionTable.by_id(ID)
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type != MapGen.NodeType.SYSTEM or n.danger < int(band.get("min_danger", 1)) \
				or n.danger > int(band.get("max_danger", 99)):
			continue
		_fresh(n)
		await OptionResolve.take(n, 0, 0)
		var w := _weight(Run.found_hull)
		if not out.has(w):
			out[w] = n
		if out.size() == WEIGHTS.size():
			break
	return out


## The derelict's page up on the real LOCAL (as the map's GO opens it).
func _open(n: MapGen.MapNode, keep_hull := false) -> LocalEventDrawer:
	_fresh(n, keep_hull)
	n.visited = true
	SectorScreen._approached_at = n.index
	SystemMapScreen._parked.erase(n.index)
	LocalEventDrawer.request(n.index, 0)
	Router.show_local()
	var d: LocalEventDrawer = null
	for i in 240:
		await _tree.process_frame
		var lo := Router.current as SectorScreen
		d = lo.get("_events") if lo != null else null
		if d != null and d.page == &"event" and not ZoomLadder.busy():
			break
	if d == null or d.page != &"event":
		return null
	for i in 10:
		if d.text != null and not d.text.done:
			d.text.skip()
		await _tree.process_frame
	return d


func _first_label(root: Node) -> Label:
	return h.first(root, func(x: Node) -> bool: return x is Label) as Label


## The box test for the event's page, as drawn.
func _page_faults(d: LocalEventDrawer) -> Array:
	var bad: Array = []
	var pr := d.panel.get_global_rect()
	if not VIEW.encloses(pr):
		bad.append("the band %s is off the screen" % pr)
	var hud := h.first(_tree.root, func(x: Node) -> bool:
		return x is HudBar and (x as Control).is_visible_in_tree()) as Control
	if hud != null and hud.get_global_rect().intersects(pr):
		bad.append("the band %s is over the HUD %s" % [pr, hud.get_global_rect()])
	var words: Rect2 = (d.get("_scroll") as Control).get_global_rect() if d.get("_scroll") != null else Rect2()
	var cards: Array[Rect2] = []
	var k := 0
	while true:
		var c := d.panel.find_child("Choice%d" % k, true, false) as Control
		if c == null:
			break
		var r := c.get_global_rect()
		if not pr.grow(0.5).encloses(r):
			bad.append("card %d %s is outside the band %s" % [k, r, pr])
		var lb := _first_label(c)
		if lb != null and not r.grow(0.5).encloses(lb.get_global_rect()):
			bad.append("card %d's words %s spill out of it %s" % [k, lb.get_global_rect(), r])
		if words.size != Vector2.ZERO and words.grow(-0.5).intersects(r.grow(-0.5)):
			bad.append("card %d %s is over the text %s" % [k, r, words])
		for j in cards.size():
			if cards[j].grow(-0.5).intersects(r.grow(-0.5)):
				bad.append("card %d is over card %d" % [k, j])
		cards.append(r)
		k += 1
	if k < 3:
		bad.append("%d cards drawn, not 3" % k)
	return bad


## Button `b`'s box against the panel `box` it sits in and its row neighbours.
func _button_faults(b: Button, box: Control) -> Array:
	var bad: Array = []
	var br := b.get_global_rect()
	var pr := box.get_global_rect()
	if not VIEW.encloses(pr):
		bad.append("%s %s is off the screen" % [box.name, pr])
	if not pr.grow(0.5).encloses(br):
		bad.append("%s %s is outside %s %s" % [b.text, br, box.name, pr])
	for sib in b.get_parent().get_children():
		if sib != b and sib is Control and (sib as Control).visible \
				and (sib as Control).get_global_rect().grow(-0.5).intersects(br.grow(-0.5)):
			bad.append("%s is over %s" % [b.text, (sib as Control).get("text")])
	return bad


## The visible button under `root` whose text starts `head`, or null.
func _button(root: Node, head: String) -> Button:
	return h.first(root, func(x: Node) -> bool:
		return x is Button and (x as Button).is_visible_in_tree() \
			and (x as Button).text.begins_with(head)) as Button


## The rail's button whose text starts `head`, or null.
func _rail_button(sc: SectorScreen, head: String) -> Button:
	var wrap: Control = sc.get("_salvage_wrap") if sc != null else null
	return _button(wrap, head) if wrap != null else null


func _pile_ids(n: MapGen.MapNode) -> Array:
	var ids: Array = []
	var pile := Run.sector_jetsam(n, false)
	if pile != null:
		for it in pile.items:
			if it is MaterialData:
				ids.append(String((it as MaterialData).id))
	ids.sort()
	return ids


## The rail on LOCAL, once the band is down and the rail has caught up.
func _rail() -> SectorScreen:
	Router.show_local()
	for i in 60:
		await _tree.process_frame
		var lo := Router.current as SectorScreen
		if lo != null and not ZoomLadder.busy() and (lo.get("_events") == null
				or (lo.get("_events") as LocalEventDrawer).page == &""):
			lo._refresh_salvage()
			await _frames(3)
			return lo
	return Router.current as SectorScreen


# ------------------------------------------------------------- 1. the card

func _names_the_frame(n: MapGen.MapNode, w: String) -> void:
	var first: HullData = null
	for layout: StringName in [&"row", &"column", &"card"]:
		LocalEventDrawer.layout = layout
		var d: LocalEventDrawer = await _open(n)
		if not h._ok("%s (%s): the derelict's page is up" % [w, layout], d != null):
			continue
		var card := d.panel.find_child("Choice0", true, false)
		var lb := _first_label(card) if card != null else null
		var words := lb.text if lb != null else ""
		h._ok("%s (%s): the claim's card names the frame before you choose: %s" % [w, layout, words],
			_names(words, w))
		var faults := _page_faults(d)
		h._ok("%s (%s): the page fits, nothing over anything%s" % [w, layout,
			"" if faults.is_empty() else ": " + "; ".join(faults)], faults.is_empty())
		var r: Dictionary = await d.choose(0)
		await _frames(2)
		h._ok("%s (%s): the claim resolves" % [w, layout], r.get("ok", false) and Run.found_hull != null)
		h._ok("%s (%s): the hull found is the weight the card named (%s)" % [w, layout, _weight(Run.found_hull)],
			_weight(Run.found_hull) == w)
		var chose := d.panel.find_child("Chose", true, false) as Label
		h._ok("%s (%s): YOU CHOSE names it: %s" % [w, layout, chose.text if chose != null else "none"],
			chose != null and _names(chose.text, w))
		if first == null:
			first = Run.found_hull
		else:
			h._ok("%s (%s): the same frame as the first visit (%s / %s)" % [w, layout,
				_sig(Run.found_hull), _sig(first)], _sig(Run.found_hull) == _sig(first))
		d.continue_on()
		await _frames(2)
	LocalEventDrawer.layout = &"column"


# -------------------------------------------------------- 2. the same frame

func _same_frame(n: MapGen.MapNode) -> void:
	_fresh(n)
	await OptionResolve.take(n, 0, 0)
	var ref := _sig(Run.found_hull)
	var seat_was := Rng.seat
	var ok := true
	for s in [7, 99991, 123456789]:
		_fresh(n)
		Rng.loot.seed = s
		for i in 50:
			Rng.loot.randi()
		Rng.seat = (seat_was + 1) % 4
		await OptionResolve.take(n, 0, 0)
		var got := _sig(Run.found_hull)
		if got != ref:
			ok = false
			print("    loot seed %d, seat %d: %s, not %s" % [s, Rng.seat, got, ref])
	Rng.seat = seat_was
	h._ok("the loot stream moved and another seat: the same frame (%s)" % ref, ok)


# ------------------------------------------------------- 3. the strip's pay

func _pays_the_strip(n: MapGen.MapNode) -> void:
	# What the strip pays here.
	_fresh(n)
	var c0 := Run.credits
	await OptionResolve.take(n, 0, 1)
	var pay := Run.credits - c0
	var crate := _pile_ids(n)
	h._ok("the strip pays credits (%d) and a crate (%s)" % [pay, ",".join(crate)],
		pay > 0 and crate.size() == 1)

	# A wreck's hull keeps LEAVE IT and has no SCRAP; its rail's width is the yardstick.
	_fresh(n)
	Run.find_hull(LootGen.roll_hull(n.danger))
	var sc := await _rail()
	var wrap: Control = sc.get("_salvage_wrap") if sc != null else null
	var leave := _button(wrap, "LEAVE IT") if wrap != null else null
	h._ok("a wreck's hull: LEAVE IT, and no SCRAP",
		leave != null and _button(wrap, "SCRAP") == null)
	var leave_w := wrap.size.x if wrap != null else 0.0

	# The claim, then SCRAP where LEAVE IT was.
	var d: LocalEventDrawer = await _open(n)
	if not h._ok("the derelict's page is up", d != null):
		return
	await d.choose(0)
	var found := Run.found_hull
	d.continue_on()
	sc = await _rail()
	var scrap := _rail_button(sc, "SCRAP")
	if not h._ok("the claimed frame has SCRAP on the rail: %s" % (scrap.text if scrap != null else "none"),
			scrap != null):
		return
	h._ok("SCRAP says the strip's credits (+%d)" % pay, scrap.text.ends_with("+%d" % pay))
	h._ok("and stands where LEAVE IT was", _rail_button(sc, "LEAVE IT") == null)
	wrap = sc.get("_salvage_wrap")
	var faults := _button_faults(scrap, wrap)
	h._ok("SCRAP fits the rail, off TRANSFER%s" % ("" if faults.is_empty() else ": " + "; ".join(faults)),
		faults.is_empty())
	h._ok("and the rail is no wider than LEAVE IT left it (%d, %d)" % [wrap.size.x, leave_w],
		wrap.size.x <= leave_w + 0.5)

	# Backed out of TRANSFER, the frame comes back with its SCRAP.
	sc._on_salvage("take_hull", found)
	await _frames(4)
	var t := h.first(_tree.root, func(x: Node) -> bool:
		return x is TransferScreen and (x as Control).is_visible_in_tree()) as TransferScreen
	if h._ok("TRANSFER opens the move", t != null):
		t._back_out()
		await _frames(6)
		sc = await _rail()
		scrap = _rail_button(sc, "SCRAP")
		h._ok("BACK OUT puts it back with SCRAP +%d" % pay, Run.found_hull == found
			and scrap != null and scrap.text.ends_with("+%d" % pay))

	# Saved and loaded, it is still there.
	SaveGame.save()
	Run.found_hull = null
	if h._ok("the run loads", SaveGame.load_into_run()):
		n = Run.node_at()
		sc = await _rail()
		scrap = _rail_button(sc, "SCRAP")
		h._ok("after a save and load, SCRAP +%d is still there" % pay,
			Run.found_hull != null and scrap != null and scrap.text.ends_with("+%d" % pay))
	if scrap == null:
		return

	# Pressed: the strip's credits and the strip's crate, once.
	var before := Run.credits
	var pile_was := _pile_ids(n)
	scrap.pressed.emit()
	await _frames(3)
	var got := _pile_ids(n)
	for id in pile_was:
		got.erase(id)
	h._ok("SCRAP pays the strip's credits (%d of %d)" % [Run.credits - before, pay],
		Run.credits - before == pay)
	h._ok("and the strip's crate (%s, the strip gave %s)" % [",".join(got), ",".join(crate)],
		got == crate)
	h._ok("and the frame is gone", Run.found_hull == null)
	sc = await _rail()
	before = Run.credits
	sc._on_salvage("scrap_hull", found)
	await _frames(2)
	h._ok("once: no SCRAP after, and pressing it again pays nothing",
		_rail_button(sc, "SCRAP") == null and Run.credits == before)

	# The system map's hull row, the other door to the same offer.
	var d2: LocalEventDrawer = await _open(n)
	if d2 == null:
		h._fail("the derelict's page did not open again")
		return
	await d2.choose(0)
	d2.continue_on()
	await _frames(2)
	Router.show_system()
	var map: SystemMapScreen = null
	for i in 240:
		await _tree.process_frame
		map = Router.current as SystemMapScreen
		if map != null and not ZoomLadder.busy() and map.get("panel") != null \
				and _button(map.get("panel"), "SCRAP") != null:
			break
	var ms := _button(map.get("panel"), "SCRAP") if map != null and map.get("panel") != null else null
	if not h._ok("the system map's hull row has SCRAP: %s" % (ms.text if ms != null else "none"), ms != null):
		return
	var panel: Control = map.get("panel")
	var pf := _button_faults(ms, panel)
	h._ok("and it fits the map's panel, off TRANSFER%s" % ("" if pf.is_empty() else ": " + "; ".join(pf)),
		pf.is_empty())
	before = Run.credits
	ms.pressed.emit()
	await _frames(3)
	h._ok("SCRAP on the map pays the strip's credits too (%d of %d)" % [Run.credits - before, pay],
		Run.credits - before == pay and Run.found_hull == null)


# ------------------------------------------- 4. a frame on offer is never lost

## What the strip pays at `n`: `{pay, crate}`, measured, the frame left alone.
func _strip(n: MapGen.MapNode) -> Dictionary:
	_fresh(n)
	var c0 := Run.credits
	await OptionResolve.take(n, 0, 1)
	return {pay = Run.credits - c0, crate = _pile_ids(n)}


## The crate's name, as the hold and the log print it.
func _crate_name(crate: Array) -> String:
	if crate.size() != 1:
		return "?"
	return String(MaterialTable.by_id(StringName(crate[0])).get("name", "?"))


## The log said `x` was scrapped for `pay`, and named its crate in SECTOR LOOT.
func _says_scrapped(what: String, x: HullData, pay: int, crate: Array) -> void:
	var line := ""
	for s in _said:
		if s.begins_with("Scrapped"):
			line = s
	var want := "Scrapped the %s for %d credits. A crate of %s is in SECTOR LOOT." % [
		x.display_name() if x != null else "?", pay, _crate_name(crate)]
	h._ok("%s: the log says \"%s\"" % [what, line if line != "" else "nothing"], line == want)


## The station nearest the start of the map, or null.
func _station() -> MapGen.MapNode:
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.STATION:
			return n
	return null


func _station_body(at: int) -> int:
	for b in SystemLayout.of(Run.map[at]).bodies:
		if b.kind == &"station":
			return b.index
	return -9


## Into the berth at the station the ship is at, the way a player docks: LOCAL
## beside it, then DOCK (as SwapTest docks). LOCAL is built afresh for the
## station's system, since the ship was on another system's LOCAL.
func _dock() -> bool:
	var at := Run.at
	SystemMapScreen._parked[at] = {"at": _station_body(at), "mode": &"rail"}
	SectorScreen._approached_at = at
	Router.show_local()
	for i in 60:
		await _tree.process_frame
		if Router.current is SectorScreen and not ZoomLadder.busy():
			break
	Router.show_station()
	await _frames(6)
	return Router.current is StationScreen and Router.docked


func _transfer() -> TransferScreen:
	return h.first(_tree.root, func(x: Node) -> bool:
		return x is TransferScreen and (x as Control).is_visible_in_tree()) as TransferScreen


## Claim A's frame and leave it on offer, fly to B and claim B's on its page:
## A's frame is cut up for its pay first. The second claim used to put B's
## frame over it, and the setter wiped A's pay.
func _second_claim(a: MapGen.MapNode, b: MapGen.MapNode) -> void:
	var strip: Dictionary = await _strip(a)
	_fresh(a)
	await OptionResolve.take(a, 0, 0)
	var first := Run.found_hull
	var d: LocalEventDrawer = await _open(b, true)
	if not h._ok("flown to a second derelict with the first frame still on offer",
			d != null and Run.found_hull == first and first != null):
		return
	var c0 := Run.credits
	_said.clear()
	var r: Dictionary = await d.choose(0)
	await _frames(2)
	h._ok("the second claim resolves on its page", r.get("ok", false))
	var got := _pile_ids(b)
	h._ok("claiming the second frame pays the first's strip credits (%d of %d)" % [
		Run.credits - c0, strip.pay], Run.credits - c0 == int(strip.pay))
	h._ok("and its crate, here under SECTOR LOOT (%s, the strip gave %s)" % [
		",".join(got), ",".join(strip.crate)], got == strip.crate)
	h._ok("and the second frame is the one on offer now",
		Run.found_hull != null and Run.found_hull != first)
	_says_scrapped("the second claim", first, int(strip.pay), strip.crate)
	d.continue_on()
	await _frames(2)


## Claim A's frame and leave it on offer, dock at a station and take the yard's
## hull: the frame is cut up for its pay first. TAKE IT used to throw it away.
## Backing out of the yard hull refunds the yard and does not bring the paid
## frame back to pay a second time.
func _yard_hull(a: MapGen.MapNode) -> void:
	var strip: Dictionary = await _strip(a)
	var d: LocalEventDrawer = await _open(a)
	if not h._ok("the derelict's page is up", d != null):
		return
	var r: Dictionary = await d.choose(0)
	h._ok("the claim resolves on its page", r.get("ok", false))
	var first := Run.found_hull
	d.continue_on()
	await _frames(2)
	var st := _station()
	if not h._ok("a station with a yard", st != null and first != null):
		return
	for raw in Run.map:
		(raw as MapGen.MapNode).ambush_rolled = true
		(raw as MapGen.MapNode).ambush_pending = false
	Run.at = st.index
	st.visited = true
	st.jetsam.clear()
	st.shop_hull = LootGen.roll_hull(st.danger)
	st.taken.erase(MapGen.OPTION_SHOP_HULL)
	Run.credits = 99999
	var docked: bool = await _dock()
	if not h._ok("docked at %s with the frame still on offer" % MapGen.star_name(st),
			docked and Run.found_hull == first):
		return
	var c0 := Run.credits
	_said.clear()
	await (Router.current as StationScreen)._on_action("take_hull", st.shop_hull)
	await _frames(4)
	var paid := int(Run._undo_move.get("paid", 0))
	var got := _pile_ids(st)
	h._ok("TAKE IT on the yard's hull pays the frame's strip credits (%d of %d, %d paid for the hull)" % [
		Run.credits - c0 + paid, strip.pay, paid], Run.credits - c0 + paid == int(strip.pay))
	h._ok("and its crate, here under SECTOR LOOT (%s, the strip gave %s)" % [
		",".join(got), ",".join(strip.crate)], got == strip.crate)
	_says_scrapped("the yard's hull", first, int(strip.pay), strip.crate)
	var t := _transfer()
	if not h._ok("TAKE IT opens the move", t != null):
		return
	t._back_out()
	await _frames(6)
	h._ok("backed out: the yard refunded, the strip's pay kept (%d of %d)" % [
		Run.credits - c0, strip.pay], Run.credits - c0 == int(strip.pay))
	h._ok("and the paid frame is not back to pay twice", Run.found_hull == null
		and Run.found_scrap_credits() == 0)
	var sb := Router.current as StationScreen
	if sb != null and sb._undock != null:
		sb._undock.pressed.emit()
		await _frames(20)
	h._ok("and the ship undocks", not Router.docked)


# --------------------------------------------- 5. SCRAP at three digits fits

## A button's words at its font and size, plus its box's side margins, inside it.
func _text_faults(b: Button) -> Array:
	var font := b.get_theme_font(&"font")
	var fs := b.get_theme_font_size(&"font_size")
	var w := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if font != null else 0.0
	var sb := b.get_theme_stylebox(&"normal")
	var pad := sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb != null else 0.0
	if w + pad > b.size.x + 0.5:
		return ["%s's words (%d, %d with its margins) spill out of it (%d)" % [b.text, w, w + pad, b.size.x]]
	return []


## `box` against the HUD along the top.
func _hud_faults(box: Control) -> Array:
	var hud := h.first(_tree.root, func(x: Node) -> bool:
		return x is HudBar and (x as Control).is_visible_in_tree()) as Control
	if hud != null and hud.get_global_rect().intersects(box.get_global_rect()):
		return ["%s %s is over the HUD %s" % [box.name, box.get_global_rect(), hud.get_global_rect()]]
	return []


## The deepest system the derelict can be at (danger 5 or 6 pays 35 x 3.0).
func _deep_system() -> MapGen.MapNode:
	var band: Dictionary = OptionTable.by_id(ID)
	var best: MapGen.MapNode = null
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.SYSTEM and n.danger >= 5 \
				and n.danger <= int(band.get("max_danger", 99)) \
				and (best == null or n.danger > best.danger):
			best = n
	return best


func _three_digits() -> void:
	var n := _deep_system()
	if not h._ok("a system at danger 5 or 6 (%s)" % (str(n.danger) if n != null else "none"), n != null):
		return
	var d: LocalEventDrawer = await _open(n)
	if not h._ok("danger %d: the derelict's page is up" % n.danger, d != null):
		return
	await d.choose(0)
	d.continue_on()
	var sc := await _rail()
	var scrap := _rail_button(sc, "SCRAP")
	var cut := int(scrap.text.get_slice("+", 1)) if scrap != null else 0
	if not h._ok("danger %d: the rail's SCRAP has three digits: %s" % [n.danger,
			scrap.text if scrap != null else "none"], scrap != null and cut >= 100):
		return
	var said := scrap.text
	var wrap: Control = sc.get("_salvage_wrap")
	var faults := _button_faults(scrap, wrap) + _text_faults(scrap) + _hud_faults(wrap)
	h._ok("SCRAP +%d fits the rail: inside it, off TRANSFER, its words inside it, the rail on screen and off the HUD%s" % [
		cut, "" if faults.is_empty() else ": " + "; ".join(faults)], faults.is_empty())

	# The system map's row, the other door to the same offer.
	Router.show_system()
	var map: SystemMapScreen = null
	for i in 240:
		await _tree.process_frame
		map = Router.current as SystemMapScreen
		if map != null and not ZoomLadder.busy() and map.get("panel") != null \
				and _button(map.get("panel"), "SCRAP") != null:
			break
	var panel: Control = map.get("panel") if map != null else null
	var ms := _button(panel, "SCRAP") if panel != null else null
	if not h._ok("the system map's row has it too: %s" % (ms.text if ms != null else "none"),
			ms != null and ms.text == said):
		return
	var pf := _button_faults(ms, panel) + _text_faults(ms) + _hud_faults(panel)
	h._ok("SCRAP +%d fits the map's panel: inside it, off TRANSFER, its words inside it, the panel on screen and off the HUD%s" % [
		cut, "" if pf.is_empty() else ": " + "; ".join(pf)], pf.is_empty())


# ----------------------------------------- 6. a 0.4.2-alpha.1 save's frame

## A VERSION 36 file has no `found_scrap`. Its hull on offer loads with LEAVE
## IT, as the build that wrote it showed, and no SCRAP it never had.
func _old_save(n: MapGen.MapNode) -> void:
	var d: LocalEventDrawer = await _open(n)
	if not h._ok("the derelict's page is up", d != null):
		return
	var r: Dictionary = await d.choose(0)
	d.continue_on()
	await _frames(2)
	var claimed := _sig(Run.found_hull)
	if not h._ok("the claim resolves on its page (%s)" % claimed, r.get("ok", false) and Run.found_hull != null):
		return
	SaveGame.save()
	var raw := FileAccess.get_file_as_string(SaveGame.path)
	var old: Variant = JSON.parse_string(raw)
	if not h._ok("the save reads back as a file", typeof(old) == TYPE_DICTIONARY):
		return
	old["version"] = 36
	old.erase("found_scrap")
	var f := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old, "", true, true))
	f.close()
	Run.found_hull = null
	if not h._ok("a version 36 save with a found hull loads", SaveGame.load_into_run()):
		return
	var sc := await _rail()
	h._ok("the hull on offer is the one saved (%s)" % _sig(Run.found_hull), _sig(Run.found_hull) == claimed)
	h._ok("with LEAVE IT on the rail and no SCRAP",
		_rail_button(sc, "LEAVE IT") != null and _rail_button(sc, "SCRAP") == null)
