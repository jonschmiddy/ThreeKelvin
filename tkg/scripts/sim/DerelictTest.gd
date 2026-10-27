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

const ID := &"derelict_hauler"
const VIEW := Rect2(0, 0, 960, 540)
const WEIGHTS: Array[String] = ["light", "medium", "heavy"]

var h := Harness.new()
var _tree: SceneTree


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
	LocalEventDrawer.quiet = false
	LocalEventDrawer.layout = &"column"
	print("")
	h.verdict("derelicttest")
	_tree.quit(1 if h._fails > 0 else 0)


# ------------------------------------------------------------------- helpers

## The system holding the derelict alone, untouched, the ship at it, whole.
func _fresh(n: MapGen.MapNode) -> void:
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
	Run.found_hull = null
	Run.hp = Run.max_hp()
	Run.heat = 0
	Run.credits = 180


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
func _open(n: MapGen.MapNode) -> LocalEventDrawer:
	_fresh(n)
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
