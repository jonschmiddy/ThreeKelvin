extends Node

## FIRST-RUN HINTS, so a friend playing alone is not lost (alpha; scratchpad
## `alpha/onboarding.md`). The first-run intro (`FirstRunIntro`) already teaches
## LOCAL, SECTOR and STARCHART. These teach what came after it, each at the moment
## it first matters, never as a wall:
##
##   go       GO on a sector-map event takes you down to LOCAL to resolve it
##   drawer   the event band's choices, and the odds printed on them
##   hand     a fight's hand: cards are dragged
##   cutaway  inside your ship: drag parts onto rings, R turns, F flips
##   wreck    a wreck is clicked to loot it
##   loot     SECTOR LOOT, beside SCAN SECTOR
##   ship     click your ship (LOCAL or the shipyard) to open it up
##
## ONE AT A TIME, a `HintCard` beside its subject. Its subject has to hold still
## for SETTLE_S first, so nothing shows mid-transition. It stays until a click:
## any click dismisses it, the click still does its own job, and only that click
## makes it seen for good (Jon: "having them automatically advance doesn't work.
## let's have them advance with a click"). Nothing times out. If its subject goes
## first, it hides unspent and shows again the next time. Seen is per
## hint in settings.cfg `[hints] <id>`, beside the intro's `[hints] intro`, in the
## same file the intro uses (`FirstRunIntro.store_path`). Under a harness that is
## the harness settings file, never the player's. Settings' SHOW HINTS AGAIN
## (`reset`) brings all of them back, the intro too.
##
## OFF UNDER HARNESSES (`TestRun.active`) unless the run asks with `-- hints`;
## `-- hinttest` turns it on by hand (`forced`). Not off under reduced motion:
## those players need hints too; only the fade goes. Nothing here is sent over
## the network, and nothing waits on it, so a co-op fight's barrier never does.
##
## It finds its subjects by looking at the screens as they are each frame, so no
## screen has to call it.

const SECTION := "hints"
## Highest first: when two could show, this one does.
const ORDER: Array[StringName] = [&"hand", &"drawer", &"go", &"cutaway", &"wreck", &"loot", &"ship"]
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


## The two lines of each hint. Graded with `tools/prose_grade.py` (grade 5.0 or
## under; all are 2.3 or under). The cutaway's names the keys as bound.
func lines(id: StringName) -> Array:
	match id:
		&"go":
			return ["GO flies you to it.", "The event plays out on LOCAL."]
		&"drawer":
			return ["Pick what to do.", "Some choices show your odds."]
		&"hand":
			return ["Drag a card onto an enemy to fire it.", "Other cards go on your own ship."]
		&"cutaway":
			return ["Drag a part onto a ring to fit it.",
				"%s turns it. %s flips it." % [Keys.describe(&"hold_turn"), Keys.describe(&"part_flip")]]
		&"wreck":
			return ["Click a wreck to loot it.", "Its parts and credits are yours."]
		&"loot":
			return ["SECTOR LOOT is what lies loose here.", "It stays until you take it."]
		&"ship":
			return ["Click your ship to open it up.", "Fit and swap parts there."]
	return []


func enabled() -> bool:
	return forced or "hints" in OS.get_cmdline_user_args() or not TestRun.active()


# ------------------------------------------------------------------ seen

func store_path() -> String:
	return FirstRunIntro.store_path()


func _load() -> void:
	_seen.clear()
	var cfg := ConfigFile.new()
	if cfg.load(store_path()) == OK:
		for id in ORDER:
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


## SHOW HINTS AGAIN: every hint and the first-run intro, unseen.
func reset() -> void:
	var cfg := ConfigFile.new()
	cfg.load(store_path())
	for id in ORDER:
		cfg.set_value(SECTION, String(id), false)
	cfg.save(store_path())
	FirstRunIntro.mark_seen(false)
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
				card.aim(p.subject, p.get("avoid", []))
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
	card.aim(p.subject, p.get("avoid", []))
	_up_t = 0.0
	_gone_t = 0.0
	_cand = &""
	shown_log.append(id)


func _close(read: bool) -> void:
	if card != null and is_instance_valid(card):
		if read:
			mark_seen(card.id)
		card.queue_free()
		if card.get_parent() != null:
			card.get_parent().remove_child(card)
	card = null
	_quiet = GAP_S


## The root of the game's picture, where the intro puts itself too.
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


## Nothing shows over the intro, the escape menu, or a run that has ended.
func _blocked() -> bool:
	if FirstRunIntro.playing != null and is_instance_valid(FirstRunIntro.playing):
		return true
	if Run.dead or Run.hull == null:
		return true
	# the escape menu is Main's (`Main.toggle_menu`), and Main sits above the
	# screens inside the game's picture, not at the scene's root
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
		&"go":
			var map := cur as SystemMapScreen
			if map == null:
				return {}
			var go := _find_button(map, "Go")
			if go == null:
				return {}
			var avoid: Array = [hud]
			var panel := _ancestor_panel(go, map)
			if panel != null:
				avoid.append(panel.get_global_rect())
			return {subject = go.get_global_rect(), avoid = avoid}
		&"drawer":
			if sc == null or sc._events == null or not is_instance_valid(sc._events):
				return {}
			var d := sc._events
			if d.page != &"event" or d._choices == null or not d._choices.is_visible_in_tree() \
					or d._choices.modulate.a < 0.99 or (d.text != null and not d.text.done):
				return {}
			return {subject = d._choices.get_global_rect(), avoid = [d.get_global_rect(), hud]}
		&"hand":
			if sc == null or not sc.fighting() or sc._hand == null or not sc._hand.is_visible_in_tree():
				return {}
			if sc._end_button == null or not sc._end_button.is_visible_in_tree() or sc._end_button.disabled:
				return {}
			var r := Rect2()
			for v in sc._hand._views:
				if v != null and is_instance_valid(v) and v.is_visible_in_tree():
					r = v.get_global_rect() if r.size == Vector2.ZERO else r.merge(v.get_global_rect())
			if r.size == Vector2.ZERO:
				return {}
			var avoid: Array = [hud, sc._end_button.get_global_rect()]
			var ship := sc._view.ship_view()
			if ship != null:
				avoid.append(_ship_box(ship))
			for i in 8:
				var art := sc._view.enemy_view(i)
				if art != null and art.is_visible_in_tree():
					avoid.append(art.get_global_rect())
			return {subject = r, avoid = avoid}
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
			var k := 0
			for raw in n.jetsam:
				var h: MapGen.Jetsam = raw
				if not h.is_wreck():
					continue
				if Run.jetsam_left(n, h) > 0:
					var art := sc._view.enemy_view(k)
					if art != null and art.is_visible_in_tree():
						return {subject = art.get_global_rect(), avoid = [hud]}
				k += 1
			return {}
		&"loot":
			if not _local_idle(sc):
				return {}
			var b := sc.find_child("SectorLoot", true, false) as Button
			if b == null or not b.is_visible_in_tree() or b.disabled:
				return {}
			return {subject = b.get_global_rect(), avoid = [hud]}
		&"ship":
			if cur is StationScreen:
				var st := cur as StationScreen
				if not st.cutaway_ready():
					return {}
				# with its name sign over it (`YardScene._names`, 16 px type at the
				# yard's 2x), so the card never stands on the name
				var box := _ship_box(st._mine_view)
				return {subject = box.grow_side(SIDE_TOP, 44.0), avoid = [hud]}
			if not _local_idle(sc):
				return {}
			var ship := sc._view.ship_view()
			if ship == null or not ship.is_visible_in_tree():
				return {}
			return {subject = _ship_box(ship), avoid = [hud]}
	return {}


## The hull's own pixels, not the box it is drawn in (a third of it at most).
func _ship_box(v: ShipView) -> Rect2:
	return v.get_global_transform() * v.ship_rect()


## LOCAL out of a fight, nothing over it, the band down: your ship can be opened.
func _local_idle(sc: SectorScreen) -> bool:
	if sc == null or not sc.cutaway_ready():
		return false
	if sc._events != null and is_instance_valid(sc._events) and sc._events.page != &"":
		return false
	return true


func _hud_rect() -> Rect2:
	if Router.hud != null and is_instance_valid(Router.hud) and Router.hud.is_visible_in_tree():
		return Router.hud.get_global_rect()
	return Rect2()


func _find_button(root: Node, nm: String) -> Button:
	for c in root.find_children(nm, "Button", true, false):
		var b := c as Button
		if b != null and b.is_visible_in_tree() and not b.disabled:
			return b
	return null


## The panel a control sits in, below `stop`: the first ancestor that is a
## PanelContainer.
func _ancestor_panel(c: Node, stop: Node) -> Control:
	var n := c.get_parent()
	while n != null and n != stop:
		if n is PanelContainer:
			return n as Control
		n = n.get_parent()
	return null
