extends Node

## FIRST-RUN HINTS, so a friend playing alone is not lost (alpha; scratchpad
## `alpha/onboarding.md`). There is NO TOUR (tutorial direction B, "learn by
## doing", Jon Oct 17): the controls are yours when the ship stops, the goal and
## the next step sit under the HUD (`GoalLine`), and each of these teaches one
## thing at the moment it first matters, never as a wall:
##
##   chart    the chart's in-range list, and its two bars (danger, fuel)
##   events   the sector map's events: click one to read it, GO flies you there
##   drawer   the event band's choices, and the odds printed on them
##   hand     a fight's hand: drag a card onto an enemy; the cost corner
##   intent   after your first card: the words over an enemy are its next move
##   endturn  nothing left to play: END TURN, and what it does
##   brace    brace held over an end of turn: it stays up, and costs heat
##   heat     heat has risen: the cap, and the hull it burns past it
##   salvage  a wreck's window: drag a part into your hold, or double-click it
##   cutaway  inside your ship: drag parts onto rings, R turns, F flips
##   wreck    a wreck is clicked to loot it
##   loot     SECTOR LOOT, beside SCAN SECTOR
##   dock     the first station: what it does, and its decks
##   fuel     the tank covers under two jumps: fuel ends runs; stations sell it
##   ship     click your ship (LOCAL or the shipyard) to open it up
##
## ONE AT A TIME, a `HintCard` beside its subject. Its subject has to hold still
## for SETTLE_S first, so nothing shows mid-transition. It stays until a click:
## any click dismisses it, the click still does its own job, and only that click
## makes it seen for good (Jon: "having them automatically advance doesn't work.
## let's have them advance with a click"). Nothing times out. If its subject goes
## first, it hides unspent and shows again the next time. Seen is per hint in
## settings.cfg `[hints] <id>` (`DisplaySettings.hints_path`), beside the welcome
## note's and the goal line's steps. Under a harness that is the harness
## settings file, never the player's. Settings' SHOW HINTS AGAIN (`reset`) brings
## all of them back, and the goal line's steps.
##
## OFF UNDER HARNESSES (`TestRun.active`) unless the run asks with `-- hints`;
## `-- hinttest` turns it on by hand (`forced`). OFF IN A PARTY too (Jon, Oct 17:
## "coop:B"): a networked run shows no hints and no goal-line steps. They still
## show on a seeded solo run. Not off under reduced motion: those players need
## hints too; only the fade goes.
##
## It finds its subjects by looking at the screens as they are each frame, so no
## screen has to call it.

const SECTION := "hints"
## Highest first: when two could show, this one does.
const ORDER: Array[StringName] = [&"hand", &"endturn", &"intent", &"brace", &"heat",
	&"drawer", &"events", &"chart", &"salvage", &"cutaway", &"wreck", &"loot", &"dock",
	&"fuel", &"ship"]
## The goal line's steps (`GoalLine`), done once: kept beside the hints, and
## cleared with them.
const STEPS: Array[StringName] = [&"step_jump", &"step_event"]
## How long a subject must hold before its hint shows, s.
const SETTLE_S := 0.6
## Quiet after one hint before the next may show, s.
const GAP_S := 1.2
## A hint shown less than this long is not dismissed by a click (the click that
## brought its subject up), s.
const GRACE_S := 0.2

## On for a harness that drives it by hand (`-- hinttest`).
var forced := false
## The hint on screen, if any.
var card: HintCard = null
## Every hint that has shown since launch, in order (for the harnesses).
var shown_log: Array[StringName] = []

var _seen := {}
var _loaded := false
var _cand: StringName = &""
var _cand_t := 0.0
var _up_t := 0.0
var _gone_t := 0.0
var _quiet := 0.0
## The fight a card has been played in (`Sig.card_played`): the intent hint's
## "after the first card".
var _played_in: Combat = null


func _ready() -> void:
	Sig.card_played.connect(func(_c: CardData) -> void: _played_in = Router.combat)


## The two lines of each hint. Graded with `tools/prose_grade.py` (grade 7.0 or
## under, ruled 2026-10-13; the ones added Oct 17 are held to 5.2). The
## cutaway's names the keys as bound; the heat and END TURN ones read the live
## cap and hand size, never a number written here.
func lines(id: StringName) -> Array:
	match id:
		&"chart":
			return ["Stars you can reach are listed here.", "Left bar is danger. Right bar is fuel."]
		&"events":
			return ["Click an event to read it.", "GO flies you to it."]
		&"drawer":
			return ["Pick what to do.", "Some choices show your odds."]
		&"hand":
			return ["Drag a card onto an enemy to fire it.", "The top left number is its energy cost."]
		&"intent":
			return ["This is what it will do", "when you press END TURN."]
		&"endturn":
			return ["Out of energy. Press END TURN.",
				"They act, then you draw %d new cards." % _hand_size()]
		&"brace":
			return ["Brace stops damage until it is used up.", "Holding it costs 1 heat a turn."]
		&"heat":
			return ["Heat. Past %d you lose 1 hull" % _heat_cap(), "for each point over, at end of turn."]
		&"salvage":
			return ["Drag a part into your hold.", "Double-click works too."]
		&"cutaway":
			return ["Drag a part onto a ring to fit it.",
				"%s turns it. %s flips it." % [Keys.describe(&"hold_turn"), Keys.describe(&"part_flip")]]
		&"wreck":
			return ["Click a wreck to loot it.", "Its parts and credits are yours."]
		&"loot":
			return ["SECTOR LOOT is what lies loose here.", "It stays until you take it."]
		&"dock":
			# ON THE LEFT, not "at the top" as the brief had it: the decks are the
			# station's section, a column down the left side (`StationScreen.DECKS`)
			return ["Stations repair, refuel and trade.", "Pick a deck on the left."]
		&"fuel":
			return ["Every jump burns fuel. Run dry and the run ends.", "Stations sell fuel."]
		&"ship":
			return ["Click your ship to open it up.", "Fit and swap parts there."]
	return []


func _hand_size() -> int:
	return Run.hand_size() if Run.hull != null else 5


func _heat_cap() -> int:
	return Run.heat_cap() if Run.hull != null else 0


func enabled() -> bool:
	if forced:
		return true
	if Net.is_networked():
		return false
	return "hints" in OS.get_cmdline_user_args() or not TestRun.active()


# ------------------------------------------------------------------ seen

func store_path() -> String:
	return DisplaySettings.hints_path()


func _load() -> void:
	_seen.clear()
	var cfg := ConfigFile.new()
	if cfg.load(store_path()) == OK:
		for id in ORDER + STEPS:
			_seen[id] = bool(cfg.get_value(SECTION, String(id), false))
	_loaded = true


func seen(id: StringName) -> bool:
	if not _loaded:
		_load()
	return bool(_seen.get(id, false))


func mark_seen(id: StringName, v: bool = true) -> void:
	var cfg := ConfigFile.new()
	cfg.load(store_path())
	cfg.set_value(SECTION, String(id), v)
	cfg.save(store_path())
	if not _loaded:
		_load()
	_seen[id] = v


## SHOW HINTS AGAIN: every hint and the goal line's steps, unseen.
func reset() -> void:
	var cfg := ConfigFile.new()
	cfg.load(store_path())
	for id in ORDER + STEPS:
		cfg.set_value(SECTION, String(id), false)
	cfg.save(store_path())
	_load()
	_close(false)
	_quiet = 0.0
	_cand = &""


## Re-read the file (a harness that wrote it behind our back).
func reload() -> void:
	_load()


# ------------------------------------------------------------------ the clock

func _process(delta: float) -> void:
	poll(delta)


## One step: keep the card on its subject, or look for the next hint. Public so
## `-- hinttest` can step it on its own clock.
func poll(delta: float) -> void:
	if not enabled():
		if card != null:
			_close(false)
		return
	_quiet = maxf(0.0, _quiet - delta)
	if card != null:
		if not is_instance_valid(card):
			card = null
		else:
			_up_t += delta
			var p := probe(card.id) if not _blocked() else {}
			if p.is_empty():
				_gone_t += delta
				if _gone_t > 0.25:
					_close(false)
			else:
				_gone_t = 0.0
				card.visible = true
				card.aim(p.subject, _with_goal(p.get("avoid", [])))
			return
	if _quiet > 0.0 or _blocked():
		_cand = &""
		return
	for id in ORDER:
		if seen(id):
			continue
		var p := probe(id)
		if p.is_empty():
			continue
		if _cand != id:
			_cand = id
			_cand_t = 0.0
		_cand_t += delta
		if _cand_t >= SETTLE_S:
			_show(id, p)
		return
	_cand = &""


## ANY CLICK DISMISSES IT, and is not taken: the click still does its own job.
func _input(e: InputEvent) -> void:
	click(e)


## A click as `_input` sees it; public for the harness. True if it dismissed one.
func click(e: InputEvent) -> bool:
	if card == null or not is_instance_valid(card):
		return false
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed or _up_t < GRACE_S:
		return false
	_close(true)
	return true


func _show(id: StringName, p: Dictionary) -> void:
	var host := _host()
	if host == null:
		return
	card = HintCard.new(id, lines(id))
	card.theme = _theme()
	host.add_child(card)
	card.aim(p.subject, _with_goal(p.get("avoid", [])))
	_up_t = 0.0
	_gone_t = 0.0
	_cand = &""
	shown_log.append(id)


## A card keeps off the goal line too (`GoalLine`), so the one thing that is
## always on screen is never covered by the thing that comes and goes.
func _with_goal(avoid: Array) -> Array:
	var g := goal_rect()
	if g.size == Vector2.ZERO:
		return avoid
	var out := avoid.duplicate()
	out.append(g)
	return out


func goal_rect() -> Rect2:
	if Router.hud == null or not is_instance_valid(Router.hud):
		return Rect2()
	return Router.hud.goal_rect()


func _close(read: bool) -> void:
	if card != null and is_instance_valid(card):
		if read:
			mark_seen(card.id)
		card.queue_free()
		if card.get_parent() != null:
			card.get_parent().remove_child(card)
	card = null
	_quiet = GAP_S


## The root of the game's picture.
func _host() -> Node:
	if Router.content == null or not Router.content.is_inside_tree():
		return null
	return Router.content.get_viewport()


## The game's theme (its pixel font), which lives on an ancestor of the screens.
func _theme() -> Theme:
	var n: Node = Router.content
	while n != null:
		if n is Control and (n as Control).theme != null:
			return (n as Control).theme
		n = n.get_parent()
	return null


## Nothing shows over the escape menu, or in a run that has ended.
func _blocked() -> bool:
	if Run.dead or Run.hull == null:
		return true
	return menu_up()


## The escape menu is up. It is Main's (`Main.toggle_menu`), and Main sits above
## the screens inside the game's picture, not at the scene's root.
func menu_up() -> bool:
	var n: Node = Router.content
	while n != null:
		if n.get_script() != null and "_menu" in n:
			return n.get("_menu") != null
		n = n.get_parent()
	return false


# ------------------------------------------------------------------ subjects

## Where hint `id`'s subject is now, if it is on screen and ready:
## {subject: Rect2, avoid: Array of Rect2}, global in the game's picture; or {}.
func probe(id: StringName) -> Dictionary:
	var cur = Router.current
	if cur == null or not is_instance_valid(cur) or not (cur as Node).is_inside_tree():
		return {}
	var hud := _hud_rect()
	var sc := cur as SectorScreen
	match id:
		&"chart":
			# the in-range list, once the camera has landed on the chart
			var ch := cur as StarchartScreen
			if ch == null or ZoomLadder.busy() or ch._neigh == null or not ch._neigh.is_visible_in_tree():
				return {}
			var rows := _union(ch._neigh.get_children())
			if rows.size == Vector2.ZERO:
				return {}
			var avoid: Array = [hud]
			var side := ch.ladder_side()
			if side != null and side.is_visible_in_tree():
				avoid.append(side.get_global_rect())
			return {subject = rows, avoid = avoid}
		&"events":
			# the map's list of events, while one is open to pick
			var map := cur as SystemMapScreen
			if map == null or ZoomLadder.busy() or map.panel == null or not is_instance_valid(map.panel):
				return {}
			if map.panel.mode != &"list" or not (map.panel as Control).is_visible_in_tree():
				return {}
			var open: Array = []
			for c in (map.panel as Node).find_children("*", "", true, false):
				if c is Control and c.has_method("set_doomed") and not c.get("finished") \
						and (c.get("press") as Callable).is_valid() and (c as Control).is_visible_in_tree():
					open.append(c)
			var r := _union(open)
			if r.size == Vector2.ZERO:
				return {}
			var avoid: Array = [hud]
			var side := map.ladder_side()
			if side != null and side.is_visible_in_tree():
				avoid.append(side.get_global_rect())
			return {subject = r, avoid = avoid}
		&"drawer":
			if sc == null or sc._events == null or not is_instance_valid(sc._events):
				return {}
			var d := sc._events
			if d.page != &"event" or d._choices == null or not d._choices.is_visible_in_tree() \
					or d._choices.modulate.a < 0.99 or (d.text != null and not d.text.done):
				return {}
			return {subject = d._choices.get_global_rect(), avoid = [d.get_global_rect(), hud]}
		&"hand":
			if not _hand_settled(sc):
				return {}
			var r := Rect2()
			for v in sc._hand._views:
				if v != null and is_instance_valid(v) and v.is_visible_in_tree():
					r = v.get_global_rect() if r.size == Vector2.ZERO else r.merge(v.get_global_rect())
			if r.size == Vector2.ZERO:
				return {}
			return {subject = r, avoid = _fight_avoid(sc, hud)}
		&"intent":
			# AFTER THE FIRST CARD, the words over an enemy: what it does when you
			# end the turn
			if not _hand_settled(sc) or _played_in == null or _played_in != Router.combat:
				return {}
			for i in 8:
				var sl := sc._view.slot(i)
				if sl == null or not sl.is_visible_in_tree() or sl.intent_hushed():
					continue
				var ir := sl.intent_rect_global()
				if ir.size.x > 2.0:
					return {subject = ir, avoid = _fight_avoid(sc, hud)}
			return {}
		&"endturn":
			# NOTHING LEFT YOU CAN PLAY: END TURN, and what it does
			if not _hand_settled(sc):
				return {}
			var cb: Combat = Router.combat
			if cb == null:
				return {}
			for c in cb.hand:
				if cb.can_play(c as CardData):
					return {}
			return {subject = sc._end_button.get_global_rect(), avoid = _fight_avoid(sc, hud)}
		&"brace":
			# BRACE CARRIED OVER AN END OF TURN (and charged its heat), still up
			var cb: Combat = Router.combat
			if not _hand_settled(sc) or cb == null or cb.brace_held <= 0 or cb.brace <= 0:
				return {}
			if sc._player_chips == null or sc._player_chips.get_child_count() == 0:
				return {}
			var chip := sc._player_chips.get_child(0) as Control
			if chip == null or not chip.is_visible_in_tree() or chip.size.x < 2.0:
				return {}
			# and off the hand under it: the card went over the first two cards' costs
			var bav := _fight_avoid(sc, hud)
			bav.append(sc._hand.get_global_rect())
			return {subject = chip.get_global_rect(), avoid = bav}
		&"heat":
			# HEAT HAS RISEN, in a fight: the gauge, the cap and its price
			if not _hand_settled(sc) or Run.heat <= 0 or Router.hud == null:
				return {}
			var hr: Rect2 = Router.hud.heat_rect()
			if hr.size == Vector2.ZERO:
				return {}
			var hav := _fight_avoid(sc, hud)
			hav.append_array(GoalLine.avoid_rects(cur))
			return {subject = hr, avoid = hav}
		&"salvage":
			# a wreck's window open with something in it
			var tv := _transfer(sc)
			if tv == null or tv._loose == null or not tv._loose.is_visible_in_tree():
				return {}
			if tv._loose.find_children("*", "ItemIcon", true, false).is_empty():
				return {}
			var avoid: Array = [hud]
			if tv._hold != null and tv._hold.is_visible_in_tree():
				avoid.append(tv._hold.get_global_rect())
			for l: Control in [tv._title, tv._loose_label]:
				if l != null and l.is_visible_in_tree():
					avoid.append(l.get_global_rect())
			return {subject = tv._loose.get_global_rect(), avoid = avoid}
		&"cutaway":
			var cut: CutawayView = null
			if sc != null:
				cut = sc._cutaway
			elif cur is StationScreen:
				cut = (cur as StationScreen)._cutaway
			if cut == null or not is_instance_valid(cut) or not cut.is_open() or cut.popup_open():
				return {}
			var pic: Rect2 = cut.get_global_transform() * cut._pic
			if pic.size.x < 4.0:
				return {}
			var avoid: Array = [hud]
			if cut._panel != null and cut._panel.is_visible_in_tree():
				avoid.append(cut._panel.get_global_rect())
			return {subject = pic, avoid = avoid}
		&"wreck":
			if not _local_idle(sc):
				return {}
			var n := Run.node_at()
			if n == null:
				return {}
			# A REAL WRECK, ONE A CLICK OPENS: the slot's own hull ink (its
			# picture's canvas is far taller than the hull), and the card kept off
			# an event's subject drawn here, which is scenery and opens nothing
			var avoid: Array = [hud]
			var subj := LocalSubject.of(sc._view)
			if subj != null:
				avoid.append_array(subj.drawn_rects())
			var k := 0
			for raw in Run.wrecks_here(n):
				var h: MapGen.Jetsam = raw
				if Run.jetsam_left(n, h) > 0:
					var sl := sc._view.slot(k)
					if sl != null and sl.is_visible_in_tree() and sl.opened.is_valid():
						return {subject = sl.get_global_transform() * sl.ink_rect(), avoid = avoid}
				k += 1
			return {}
		&"loot":
			if not _local_idle(sc):
				return {}
			var b := sc.find_child("SectorLoot", true, false) as Button
			if b == null or not b.is_visible_in_tree() or b.disabled:
				return {}
			return {subject = b.get_global_rect(), avoid = [hud]}
		&"dock":
			# THE FIRST STATION, once the dock has landed: its decks
			var st := cur as StationScreen
			if st == null or ZoomLadder.busy() or st._cutaway != null:
				return {}
			var cells: Array = []
			for v in st._tabs.values():
				if v is Control and (v as Control).is_visible_in_tree():
					cells.append(v)
			var r := _union(cells)
			if r.size == Vector2.ZERO:
				return {}
			return {subject = r, avoid = [hud]}
		&"fuel":
			# THE TANK COVERS UNDER TWO OF THE JUMPS ON OFFER, out of a fight on a
			# screen that is still
			if Router.hud == null or ZoomLadder.busy() or not _fuel_low():
				return {}
			if not (cur is StarchartScreen or cur is SystemMapScreen or _local_idle(sc)):
				return {}
			var fr: Rect2 = Router.hud.fuel_rect()
			if fr.size == Vector2.ZERO:
				return {}
			# and off the side bar, the toolbar and the scene's own pieces: the
			# readout is in the corner, so the card lands among them
			return {subject = fr, avoid = GoalLine.avoid_rects(cur)}
		&"ship":
			if cur is StationScreen:
				var st := cur as StationScreen
				if not st.cutaway_ready():
					return {}
				# with its name sign over it (`YardScene._names`, 16 px type at the
				# yard's 2x), so the card never stands on the name
				var box := _ship_box(st._mine_view)
				return {subject = box.grow_side(SIDE_TOP, 44.0), avoid = [hud]}
			# NOT BEFORE THE FIRST JUMP: the first screen of a run says one thing,
			# the goal line's (open STARCHART), and there is nothing to fit yet
			if not _local_idle(sc) or Run.jumps < 1:
				return {}
			var ship := sc._view.ship_view()
			if ship == null or not ship.is_visible_in_tree():
				return {}
			return {subject = _ship_box(ship), avoid = [hud]}
	return {}


## The hull's own pixels, not the box it is drawn in (a third of it at most).
func _ship_box(v: ShipView) -> Rect2:
	return v.get_global_transform() * v.ship_rect()


## LOCAL out of a fight, nothing over it, and nothing on its way: no camera
## move, no event band up, going down, or waiting to come up (`deferred`,
## `LocalEventDrawer.pending`). The ship hint used to show in the 0.6 s between
## GO's landing and the band rising, and hide unread (tutorial audit, 0.44 s).
func _local_idle(sc: SectorScreen) -> bool:
	if sc == null or not sc.cutaway_ready() or ZoomLadder.busy():
		return false
	if not LocalEventDrawer.pending.is_empty():
		return false
	var d := sc._events
	if d != null and is_instance_valid(d) and (d.page != &"" or d.visible or not d.deferred.is_empty()):
		return false
	return true


## A fight's hand is up and yours to play: the band settled, END TURN live.
func _hand_settled(sc: SectorScreen) -> bool:
	if sc == null or not sc.fighting() or sc._hand == null or not sc._hand.is_visible_in_tree():
		return false
	if sc._hold or sc._opening:
		return false
	return sc._end_button != null and sc._end_button.is_visible_in_tree() and not sc._end_button.disabled


## What a card in a fight keeps off: the HUD, END TURN, the hand, the hulls and
## the words over them.
func _fight_avoid(sc: SectorScreen, hud: Rect2) -> Array:
	var avoid: Array = [hud, sc._end_button.get_global_rect()]
	var ship := sc._view.ship_view()
	if ship != null:
		avoid.append(_ship_box(ship))
	# your name, hull and chips under it
	if sc._self_plate != null and sc._self_plate.is_visible_in_tree():
		avoid.append(sc._self_plate.get_global_rect())
	for i in 8:
		var sl := sc._view.slot(i)
		if sl == null or not sl.is_visible_in_tree():
			continue
		avoid.append(sl.get_global_transform() * sl.ink_rect())
		var ir := sl.intent_rect_global()
		if ir.size.x > 0.0:
			avoid.append(ir)
	return avoid


## The wreck's (or an event reward's) window, if one is open on LOCAL.
func _transfer(sc: SectorScreen) -> TransferView:
	if sc == null:
		return null
	if sc._transfer != null and is_instance_valid(sc._transfer) and sc._transfer.is_visible_in_tree():
		return sc._transfer
	var d := sc._events
	if d != null and is_instance_valid(d) and d._transfer != null and is_instance_valid(d._transfer) \
			and d._transfer.is_visible_in_tree():
		return d._transfer
	return null


## Fewer than two of the jumps in range paid for: the dearest one on offer,
## twice, is more than the tank holds.
func _fuel_low() -> bool:
	if Run.hull == null or Run.map.is_empty() or Run.node_at() == null:
		return false
	var dear := 0
	for raw in Run.in_range():
		var n: MapGen.MapNode = raw
		if n == Run.node_at() or not n.sensed:
			continue
		dear = maxi(dear, Run.fuel_cost_to(n))
	if dear == 0:
		dear = Run.fuel_max_hop()
	return Run.fuel < dear * 2


func _hud_rect() -> Rect2:
	if Router.hud != null and is_instance_valid(Router.hud) and Router.hud.is_visible_in_tree():
		return Router.hud.get_global_rect()
	return Rect2()


## The global box round the visible ones of `nodes`.
func _union(nodes: Array) -> Rect2:
	var r := Rect2()
	for c in nodes:
		if c is Control and (c as Control).is_visible_in_tree() and (c as Control).size.x > 0.0:
			var g := (c as Control).get_global_rect()
			r = g if r.size == Vector2.ZERO else r.merge(g)
	return r
