class_name LocalEventDrawer
extends Control

## Jon picked the low band, A. Events resolve here through `OptionResolve`, the one rule.
## Three layouts on one switch so Jon can pick from stills; the flow and words are identical.
## Why: docs/why/LocalEventDrawer.md#event-drawer

## Up or down: the bar under the view redraws (OPEN IT only while it is down).
signal changed

## The band's cap (the fight hand's height) and the card's, game px.
const H := 190.0
const CARD_W := 320.0
const CARD_MAX_H := 330.0
## How long it takes to lift or drop, to pop the card, and to fade the choices
## in, s.
const LIFT_S := 0.28
const POP_S := 0.16
const CHOICES_S := 0.15
## The fade in from the map's zoom, s.
const FADE_S := 0.22
## The choices' column width, in the column layout.
const COL_W := 300.0
## D's buttons sit this far down, measured on stills, to line up with the title's baseline.
const D_BUTTONS_DROP := 3

## Jon picked the column ("Yeah, I like the column").
static var layout: StringName = &"column"
## `-- localeventtest`: the screens a fight or a death would swap in are not
## opened; `fought` and `died` say they would have been.
static var quiet := false
var fought := false
var died := false
## An event asked for from the map, to open when LOCAL comes up: [node, option].
static var pending: Array = []
## The event last opened on LOCAL, for the bar's line and OPEN IT: [node, option].
static var last: Array = []

var screen: Control = null
var node: MapGen.MapNode = null
## The option up, the choice taken, and what `OptionResolve.take` said.
var opt := -1
var choice := -1
var out: Dictionary = {}
## &"event", &"result" or &"" (down).
var page: StringName = &""
## The band's (or the card's) height now, fitted to what it holds.
var height := H
var panel: PanelContainer
var _box: VBoxContainer
var text: SignalText
var _scroll: ScrollContainer
var _choices: Control
var _conseq: Label
var _transfer: TransferView = null
var _tw: Tween = null
var _busy := false
var _gen := 0
## Up on screen now: a new page resizes in place rather than lifting again.
var _up := false


# --------------------------------------------------------------- the map's half

## The map asks for event i at node `index` to be opened when LOCAL comes up.
static func request(index: int, i: int) -> void:
	pending = [index, i]


## Which body holds option i (-1 the star, -2 none).
static func body_of(n: MapGen.MapNode, i: int) -> int:
	return SystemLayout.of(n).place_of(i)


## The event about to open on LOCAL here or open there now (`pending` first,
## so LOCAL's sky can compose for it before the band is up), or -1.
static func open_here(n: MapGen.MapNode) -> int:
	if n == null:
		return -1
	if pending.size() >= 2 and int(pending[0]) == n.index:
		var p := int(pending[1])
		return p if p >= 0 and p < n.options.size() and here_now(n, p) else -1
	return bar_option(n)


## Whether the ship is parked where option i stands (the map leaves it there).
## (an option placed nowhere, -2, is at no place a ship can be: `is_place`)
static func here_now(n: MapGen.MapNode, i: int) -> bool:
	var b := body_of(n, i)
	# a comet's reading: here once the ship has met the comet on a spot (`CometCatch`)
	if b == SystemLayout.COMET:
		return CometPath.caught_at(n) >= 0
	var d: Dictionary = ParkedShips.spots.get(n.index, {})
	if d.is_empty():
		return true
	return SystemLayout.is_place(b) and int(d.get("at", -9)) == b


## The bar's event, if it has one here: the last opened, while the ship is still
## where it stands.
static func bar_option(n: MapGen.MapNode) -> int:
	if n == null or last.size() < 2 or int(last[0]) != n.index:
		return -1
	var i := int(last[1])
	if i < 0 or i >= n.options.size() or not here_now(n, i):
		return -1
	return i


## "THE AUTOMATIC DOCK · PARTIAL · 2 MORE IN THIS SECTOR", or "" for the plain bar.
static func bar_line(n: MapGen.MapNode) -> String:
	var i := bar_option(n)
	if i < 0:
		return ""
	var title := String(OptionTable.by_id(n.options[i]).get("title", "")).to_upper()
	var st := EncounterDrawer.option_state(n, i)
	if st.kind == &"open":
		return "%s · OPEN" % title
	if st.kind == &"left":
		return "%s · LEFT ALONE, STILL OPEN" % title
	var more := EncounterDrawer.untaken(n).size()
	return "%s · %s · %d MORE IN THIS SECTOR" % [title, st.word, more]


## Whether OPEN IT is offered: the bar's event is still there to take.
static func can_reopen(n: MapGen.MapNode) -> bool:
	var i := bar_option(n)
	if i < 0:
		return false
	var k: StringName = EncounterDrawer.option_state(n, i).kind
	return k == &"open" or k == &"left"


# --------------------------------------------------------------- the screen's half

## LOCAL is GO (Jon, Oct 21): its own doors open the event at the ship's place as GO would.
## Why: docs/why/LocalEventDrawer.md#attach-and-auto-open
static func attach(on: Control, fighting: bool, auto: bool = false, held: bool = false) -> LocalEventDrawer:
	var d := LocalEventDrawer.new()
	d.screen = on
	d.node = Run.node_at()
	on.add_child(d)
	var want: Array = []
	if not pending.is_empty():
		want = pending
		pending = []
		# (GO, pressed: this visit's event opened, so LOCAL again after NOT NOW
		# leaves it closed, `auto_open`)
		if not fighting and d.node != null and int(want[0]) == d.node.index:
			_auto[d.node.index] = visit_key(d.node)
	elif auto and not fighting and d.node != null:
		var i := auto_open(d.node)
		if i >= 0:
			want = [d.node.index, i]
	if not want.is_empty():
		if not fighting and d.node != null and int(want[0]) == d.node.index:
			# On the one camera the band lifts after the move down lands, with no dip to black.
			d.deferred = want.duplicate()
			# (what LOCAL composes its scene for -- the event's subject, its sky -- is
			# this event from the first frame, as it was when the band opened at once)
			last = [d.node.index, int(want[1])]
			if held:
				return d
			var go := func() -> void:
				if is_instance_valid(d) and d.is_inside_tree() and not d.deferred.is_empty():
					d.deferred = []
					d.open(int(want[1]))
			if not ZoomLadder.when_landed(go):
				d.deferred = []
				d._fade_in()
				d.open(int(want[1]))
	return d


## The event held for LOCAL's own arrival, opened now it has settled (or been
## pressed through).
func open_held() -> void:
	if deferred.size() < 2 or not is_inside_tree():
		return
	var i := int(deferred[1])
	deferred = []
	_fade_in()
	open(i)


## Which visit's event LOCAL has opened, by system: `visit_key` (GO's press or
## LOCAL's own door).
static var _auto := {}


## The place the ship is and the visit it is on (`SectorScreen._visit`).
static func visit_key(n: MapGen.MapNode) -> String:
	return "%d:%d" % [Run.site_here(n), SectorScreen._visit(n)]


## The first still-open event at the ship's place, as GO opens it. NOT NOW keeps it closed.
static func auto_open(n: MapGen.MapNode) -> int:
	if n == null:
		return -1
	var site := Run.site_here(n)
	if not SystemLayout.is_place(site):
		return -1
	var key := visit_key(n)
	if str(_auto.get(n.index, "")) == key:
		return -1
	for bc in SystemLayout.of(n).beacons_at(site):
		var i := int(bc.opt)
		if i < 0 or i >= n.options.size() or OptionTable.by_id(n.options[i]).is_empty():
			continue
		var k: StringName = EncounterDrawer.option_state(n, i).kind
		if k == &"open" or k == &"left":
			_auto[n.index] = key
			return i
	return -1


## Forget which visits' events were opened: one system (a jump in) or all.
static func forget_auto(index: int = -1) -> void:
	if index < 0:
		_auto.clear()
	else:
		_auto.erase(index)


## An event asked for here, waiting for the move to land (`attach`): handed
## back to `pending` if this LOCAL is thrown away unshown.
var deferred: Array = []



func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _moving() -> bool:
	return Router.animating() and is_inside_tree()


## Where the band or the card sits: 0 up, 1 down.
func _place(down: float) -> void:
	if layout == &"card":
		set_anchors_preset(Control.PRESET_FULL_RECT)
		offset_left = 0.0
		offset_top = 0.0
		offset_right = 0.0
		offset_bottom = 0.0
		return
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = 0.0
	offset_right = 0.0
	offset_top = roundf(-height + height * down)
	offset_bottom = roundf(height * down)


func _lift() -> void:
	visible = true
	if _tw != null:
		_tw.kill()
	var again := _up
	_up = true
	if layout == &"card":
		_place(0.0)
		_seat_card()
		if again or not _moving():
			panel.modulate.a = 1.0
			return
		var to := panel.position
		panel.modulate.a = 0.0
		_tw = create_tween().set_parallel()
		_tw.tween_property(panel, "modulate:a", 1.0, POP_S)
		# up into place a few whole pixels, not a smooth scale
		_tw.tween_method(func(k: float) -> void: panel.position = Vector2(to.x, to.y + roundf(6.0 * (1.0 - k))), 0.0, 1.0, POP_S)
		return
	if again or not _moving():
		_place(0.0)
		return
	_bar(false)
	_tw = create_tween()
	_tw.tween_method(_place, 1.0, 0.0, LIFT_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _drop() -> void:
	OutcomeRow.settle(self)
	page = &""
	_up = false
	if _tw != null:
		_tw.kill()
	var gone := func() -> void:
		visible = false
		changed.emit()
		_bar(true)
	if not _moving():
		_place(1.0)
		gone.call()
		return
	_tw = create_tween()
	if layout == &"card":
		_tw.tween_property(panel, "modulate:a", 0.0, POP_S * 0.8)
		_tw.tween_callback(gone)
		return
	_tw.tween_method(_place, 0.0, 1.0, _drop_s()).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_callback(gone)


## The bar waits for the band, then eases up after the drop (Jon, Oct 14).
func _bar(up: bool) -> void:
	if screen == null or not is_instance_valid(screen):
		return
	if not up:
		if screen.has_method(&"_shut_drawer"):
			screen.call(&"_shut_drawer")
	elif screen.has_method(&"_open_drawer"):
		screen.call(&"_open_drawer", not _moving())


## Eased both ends, staying under DROP_MAX_PX a frame: the cubic ease-in hit 29 px a frame.
## Dissolve and shutter were the other options (Jon, Oct 14) and are in git.
## Why: docs/why/LocalEventDrawer.md#drop-easing
const DROP_MAX_PX := 10.0

## A sine in-out's fastest frame is PI/2 times its average, so the time a
## height needs to stay under DROP_MAX_PX a frame; never quicker than the old drop.
func _drop_s() -> float:
	return maxf(LIFT_S * 0.8, height * PI * 0.5 / (DROP_MAX_PX * 60.0))


## Out of the map's zoom: LOCAL comes up from black.
func _fade_in() -> void:
	if not _moving():
		return
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 1)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(black)
	var tw := black.create_tween()
	tw.tween_property(black, "color:a", 0.0, FADE_S)
	tw.tween_callback(black.queue_free)


## A click or a key while the text is still arriving finishes it, and is spent.
func _input(e: InputEvent) -> void:
	if page == &"" or text == null or text.done:
		return
	var press := (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) \
		or (e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo)
	if press:
		text.skip()
		get_viewport().set_input_as_handled()


func _frame() -> void:
	if panel != null:
		panel.queue_free()
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := UITheme.flat(Color(UITheme.PANEL, 0.97), UITheme.LINE, 0, 6, 10)
	if layout == &"card":
		sb.set_border_width_all(1)
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 8
		panel.custom_minimum_size.x = CARD_W
	else:
		sb.border_width_left = 0
		sb.border_width_right = 0
		sb.border_width_bottom = 0
		sb.border_width_top = 1
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4)
	panel.add_child(_box)
	text = null
	_scroll = null
	_choices = null


## The text, in a scroll that only scrolls when the band is at its cap.
func _text_box(words: String, ink: Color) -> ScrollContainer:
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text = SignalText.new()
	text.by_word = true
	text.ink = ink
	text.text = words
	text.name = "Text"
	_scroll.add_child(text)
	return _scroll


## Fit the band (or the card) to what it holds, then bring it up and start the
## text. A frame first, so the text has its width and knows its lines.
func _fit_and_show() -> void:
	_gen += 1
	var g := _gen
	height = H
	visible = true
	if layout != &"card" and not _up:
		_place(1.0)
	if _choices != null:
		_choices.modulate.a = 0.0
	panel.modulate.a = 0.0 if layout == &"card" and not _up else 1.0
	if is_inside_tree():
		await get_tree().process_frame
		await get_tree().process_frame
	if g != _gen or panel == null:
		return
	var cap := CARD_MAX_H if layout == &"card" else H
	if text != null and _scroll != null:
		var want := text.custom_minimum_size.y
		_scroll.custom_minimum_size.y = 0.0
		var rest := panel.get_combined_minimum_size().y
		# D's text stands BESIDE its table, not over it: the table's height is
		# not taken off the text's
		var lane := _scroll.get_parent() as Control
		if page == &"result" and lane != null and lane.name == &"ResultLane":
			rest -= lane.get_combined_minimum_size().y
		elif page == &"result" and lane != null and lane.name == &"ResultLeft":
			# D's: the text, the title and YOU CHOSE beside the buttons and
			# the table; only the left column's height is the text's to fit
			rest += lane.get_combined_minimum_size().y - (lane.get_parent() as Control).get_combined_minimum_size().y
		_scroll.custom_minimum_size.y = minf(want, maxf(cap - rest, 12.0))
	height = minf(cap, panel.get_combined_minimum_size().y)
	if layout == &"card":
		panel.size = Vector2(CARD_W, height)
	var was_up := _up
	_lift()
	if not was_up:
		changed.emit()
	if text != null:
		text.finished.connect(_text_done, CONNECT_ONE_SHOT)
		text.play()
	else:
		_text_done()


## The text is all here: the choices (or the buttons) fade in and take clicks.
func _text_done() -> void:
	if page == &"result":
		OutcomeRow.fly(self)
	if _choices == null:
		return
	if not _moving():
		_choices.modulate.a = 1.0
		return
	var tw := _choices.create_tween()
	tw.tween_property(_choices, "modulate:a", 1.0, CHOICES_S)


## The card sits nearest the middle that covers least of the ships and the event's subject.
func _seat_card() -> void:
	var area := Rect2(Vector2.ZERO, size)
	area.size.y -= 40.0
	var w := CARD_W
	var h := height
	var avoid := _avoid_rects()
	var mid := area.get_center() - Vector2(w, h) * 0.5
	var best := mid
	var best_score := INF
	for dy in [0.0, -40.0, 40.0, -80.0, 80.0, -120.0, 120.0]:
		for dx in [0.0, 40.0, -40.0, 80.0, -80.0, 120.0, -120.0, 180.0, -180.0, 240.0, -240.0]:
			var p := (mid + Vector2(dx, dy)).round()
			p.x = clampf(p.x, 8.0, area.end.x - w - 8.0)
			p.y = clampf(p.y, 8.0, maxf(8.0, area.end.y - h - 4.0))
			var r := Rect2(p, Vector2(w, h))
			var hit := 0.0
			for a: Rect2 in avoid:
				hit += r.intersection(a).get_area()
			# covering anything costs far more than being off the middle
			var score := hit * 100.0 + p.distance_to(mid)
			if score < best_score:
				best_score = score
				best = p
	panel.position = best


## Your ship and the encounter's subject, in this control's px.
func _avoid_rects() -> Array:
	var rs: Array = []
	var at := UiRect.of(self).position
	var view = screen.get("_view") if screen != null else null
	if view == null:
		return rs
	# EVERY HULL IN THE VIEW: yours, a partner's, a contact the event is about
	for c in _hulls(view):
		if c is ShipView:
			var sr := (c as ShipView).ship_rect()
			rs.append(Rect2(sr.position + (c as Control).global_position - at, sr.size).grow(6.0))
		elif c is EnemyArt:
			var er := Rect2((c as EnemyArt).used_rect())
			rs.append(Rect2(er.position + (c as Control).global_position - at, er.size).grow(6.0))
	var sky = view.get("backdrop")
	if sky != null:
		for e: Array in sky.get("_near"):
			var nd: Node2D = e[0]
			var r := float(e[3]) if float(e[3]) > 0.0 else 110.0
			var c := nd.global_position - at
			rs.append(Rect2(c - Vector2(r, r * 0.6 if e[3] == 0.0 else r), Vector2(r * 2.0, (r * 0.6 if e[3] == 0.0 else r) * 2.0)))
			break
	return rs


func _hulls(n: Node) -> Array:
	var outh: Array = []
	for c in n.get_children():
		if not (c is CanvasItem) or not (c as CanvasItem).visible:
			continue
		if c is ShipView or c is EnemyArt:
			outh.append(c)
		else:
			outh.append_array(_hulls(c))
	return outh


# --------------------------------------------------------------- the event

## Option i's page: its title, tags and where it is, its whole text, its choices.
func open(i: int) -> void:
	if node == null or i < 0 or i >= node.options.size():
		return
	OutcomeRow.settle(self)
	opt = i
	choice = -1
	out = {}
	last = [node.index, i]
	page = &"event"
	var o := OptionTable.by_id(node.options[i])
	_frame()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UITheme.body(String(o.get("title", "")).to_upper(), UITheme.HOT, UITheme.FS_SMALL))
	var where := "%s · %s" % [_tags(o), _place_line(i)]
	if layout != &"card":
		head.add_child(UITheme.body(_tags(o), EncounterDrawer.tag_colour(o), UITheme.FS_SMALL))
		head.add_child(UITheme.body(_place_line(i), UITheme.COLD, UITheme.FS_SMALL))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_conseq = UITheme.body("", UITheme.WARN, UITheme.FS_SMALL)
	head.add_child(_conseq)
	var later := Widgets.button("NOT NOW", not_now)
	later.name = "NotNow"
	head.add_child(later)
	_box.add_child(head)
	if layout == &"card":
		var wl := UITheme.body(where, EncounterDrawer.tag_colour(o), UITheme.FS_SMALL)
		wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(wl)
	var words := String(o.get("body", ""))
	if EncounterDrawer.option_state(node, i).kind == &"left":
		words = "You walked away from this. It is still open. " + words
	var cards := _choice_cards(i, o)
	if layout == &"column":
		var lane := HBoxContainer.new()
		lane.add_theme_constant_override("separation", 10)
		lane.add_child(_text_box(words, UITheme.CHILL))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		col.custom_minimum_size.x = COL_W
		for c in cards:
			col.add_child(c)
		_choices = col
		lane.add_child(col)
		_box.add_child(lane)
	else:
		_box.add_child(_text_box(words, UITheme.CHILL))
		var row: BoxContainer = VBoxContainer.new() if layout == &"card" else HBoxContainer.new()
		row.add_theme_constant_override("separation", 4 if layout == &"card" else 6)
		for c in cards:
			row.add_child(c)
		_choices = row
		_box.add_child(row)
	_fit_and_show()


## The choice cards, as the map's panel drew them (`EncounterDrawer.choice_card`),
## compact: as tall as their two lines.
func _choice_cards(i: int, o: Dictionary) -> Array:
	var cards: Array = []
	var choices: Array = o.get("choices", [])
	var names := ", ".join(_rivals(i).map(func(j: int) -> String:
		return String(OptionTable.by_id(node.options[j]).get("title", "")).to_upper()))
	for j in choices.size():
		var c: Dictionary = choices[j]
		var card := EncounterDrawer.choice_card(node, i, j, c, o, func(_ii: int, jj: int) -> void: choose(jj))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 0)
		card.name = "Choice%d" % j
		cards.append(card)
		# WHAT IT WOULD CLOSE, while you point at a choice that takes the event
		# (the map's panel said the same; walking away closes nothing)
		if names != "" and not bool(c.get("stay", false)) and OptionResolve.affordable(c):
			card.mouse_entered.connect(func() -> void: _conseq.text = "WILL MAKE %s UNAVAILABLE" % names)
			card.mouse_exited.connect(func() -> void: _conseq.text = "")
	return cards


## NOT NOW: it drops, the bar offers OPEN IT.
func not_now() -> void:
	if _busy:
		return
	_drop()


## Choice j, through the one rule. Returns what `OptionResolve.take` said.
## Not until the text is all here (a click before then finishes the text).
func choose(j: int) -> Dictionary:
	if _busy or page != &"event" or node == null:
		return {}
	if text != null and not text.done:
		text.skip()
		return {}
	var o := OptionTable.by_id(node.options[opt])
	var choices: Array = o.get("choices", [])
	if j < 0 or j >= choices.size() or not OptionResolve.affordable(choices[j]):
		return {}
	_busy = true
	choice = j
	var r: Dictionary = await OptionResolve.take(node, opt, j)
	_busy = false
	out = r
	if not r.get("ok", false):
		if r.get("why", "") == "too_late":
			var who := String(r.get("who", ""))
			Run.log_line("%s is already gone.%s" % [String(o.get("title", "")),
				" %s took it." % who.to_upper() if who != "" else ""], &"them")
			_drop()
		return r
	if r.get("dead", false):
		_drop()
		died = true
		if not quiet:
			Router.show_game_over()
		return r
	# A FIGHT WITH NOTHING TO READ goes straight to the fight (`OptionResolve`'s
	# `fight_now`): its line is in the log, and the hand takes the band
	if r.get("fight_now", false):
		_drop()
		_fight()
		return r
	_result()
	return r


# --------------------------------------------------------------- the result

## B's receipt, beside the text, game px.
const RECEIPT_W := 340.0
## E's plates at their widest before a row wraps under, game px.
const PRIZES_W := 330.0

func _result() -> void:
	# a re-shown result (REWARD shut, a look changed) lands C's flights first
	OutcomeRow.settle(self)
	page = &"result"
	var o := OptionTable.by_id(node.options[opt])
	var choices: Array = o.get("choices", [])
	var res: Dictionary = out.get("res", {})
	var fight := bool(res.get("fight", false)) and not bool(out.get("stay", false))
	_frame()
	var word := "RESOLVED"
	var ink := UITheme.CHILL
	if out.get("stay", false):
		word = "LEFT ALONE · STILL OPEN"
		ink = UITheme.COLD
	elif out.get("checked", false):
		word = SkillCheck.band_name(out.band)
		ink = SkillCheck.band_colour(out.band)
	elif fight:
		word = "ENGAGED"
		ink = UITheme.LEAVE
	# THE HEAD: the event, how it went, what you chose
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UITheme.body(String(o.get("title", "")).to_upper(), UITheme.HOT, UITheme.FS_SMALL))
	var band := UITheme.body(word, ink, UITheme.FS_HEAD)
	band.name = "Band"
	head.add_child(band)
	head.name = "Head"
	_box.add_child(head)
	var chose := "YOU CHOSE: " + OptionTable.label_of(choices[choice], node).to_upper() \
		if choice >= 0 and choice < choices.size() else ""
	if out.get("checked", false):
		chose += " · " + String(out.get("odds", ""))
	var cl := UITheme.body(chose, UITheme.COLD, UITheme.FS_SMALL)
	cl.name = "Chose"
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(cl)
	# Looks A to E are Jon's pick of how the outcome shows: changes, receipt, flyer, table.
	# Why: docs/why/LocalEventDrawer.md#outcome-looks
	var look := OutcomeRow.look
	var said := _text_box(String(res.get("text", "")), UITheme.CHILL if ink == UITheme.COLD else ink)
	var receipt: Control = null
	if look == &"B":
		receipt = OutcomeRow.ledger(out, RECEIPT_W if layout != &"card" else CARD_W - 20.0)
	# D puts a table on the right with buttons at its top; E adds drawn-big arrivals to its left.
	# Why: docs/why/LocalEventDrawer.md#outcome-looks
	var right: VBoxContainer = null
	var prizes: Control = null
	if look == &"E":
		prizes = OutcomeRow.prizes(out, PRIZES_W if layout != &"card" else CARD_W - 20.0)
	var tab: Control = null
	if look == &"D" or look == &"E":
		tab = OutcomeRow.table(out, prizes != null, OutcomeRow.D_FS if look == &"D" else UITheme.FS_SMALL, look == &"D")
	# D's buttons are at the top right level with the title (Jon, Oct 19), the table centred under.
	# Why: docs/why/LocalEventDrawer.md#outcome-looks
	var d_top := look == &"D"
	if receipt != null and layout != &"card":
		var lane := HBoxContainer.new()
		lane.add_theme_constant_override("separation", 14)
		lane.add_child(said)
		lane.add_child(receipt)
		_box.add_child(lane)
	elif (tab != null or prizes != null or d_top) and layout != &"card":
		var lane2 := HBoxContainer.new()
		lane2.name = "ResultLane"
		lane2.add_theme_constant_override("separation", 16)
		if d_top:
			# Title and text in one left column, so the right column starts at the band's top.
			var left := VBoxContainer.new()
			left.name = "ResultLeft"
			left.add_theme_constant_override("separation", 4)
			left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for c: Control in [head, cl]:
				_box.remove_child(c)
				left.add_child(c)
			left.add_child(said)
			lane2.add_child(left)
		else:
			lane2.add_child(said)
		if prizes != null:
			# its foot on the band's floor beside the buttons' column
			prizes.size_flags_vertical = Control.SIZE_SHRINK_END
			lane2.add_child(prizes)
		right = VBoxContainer.new()
		right.add_theme_constant_override("separation", 6)
		right.size_flags_horizontal = Control.SIZE_SHRINK_END
		var push := Control.new()
		push.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if d_top:
			# No gaps of its own, so the two pushes centre the table exactly.
			right.add_theme_constant_override("separation", 0)
			push.custom_minimum_size.y = 6.0
		right.add_child(push)
		if tab != null:
			right.add_child(tab)
		if d_top:
			# as much room under the table as over it: centred under the buttons
			var push2 := Control.new()
			push2.size_flags_vertical = Control.SIZE_EXPAND_FILL
			right.add_child(push2)
		lane2.add_child(right)
		_box.add_child(lane2)
	else:
		_box.add_child(said)
		if receipt != null:
			_box.add_child(receipt)
	# THE OUTCOME AS ONE ROW, the buttons at the end of it
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	if look == &"A" or look == &"C":
		foot.add_child(OutcomeRow.line(out, look))
	else:
		if look == &"today":
			for r in out.get("bill", []):
				foot.add_child(UITheme.body(String(r.name), UITheme.COLD, UITheme.FS_SMALL))
				var v := UITheme.body(String(r.text), r.tone as Color, UITheme.FS_SMALL)
				v.custom_minimum_size.x = 22
				v.add_to_group(OutcomeRow.GROUP)
				v.set_meta(&"outcome_text", "%s %s" % [r.name, r.text])
				foot.add_child(v)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(sp)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	# CONTINUE STAYS WHERE IT IS: at its own height on the band's floor, whatever
	# the outcome beside it stands as tall as
	buttons.size_flags_vertical = Control.SIZE_SHRINK_END
	if out.get("stay", false):
		var again := Widgets.button("CHOOSE AGAIN", func() -> void: open(opt))
		again.name = "ChooseAgain"
		buttons.add_child(again)
	# WHEN ANYTHING LANDED ON THE PILE, read off the pile (`shows_reward`): a
	# crate of material said CONTINUE here and was left under SECTOR LOOT
	if OptionResolve.shows_reward(out) and not Run.dead:
		var claim := Widgets.commit(Widgets.button(LOOT_WORD, open_reward), 5, 10)
		claim.name = "Reward"
		claim.disabled = Run.jetsam_left(node, Run.sector_jetsam(node, false)) <= 0
		buttons.add_child(claim)
	if fight:
		var go := Widgets.button("THEY ARE FIRING", func() -> void:
			_drop()
			_fight())
		go.name = "TheyAreFiring"
		buttons.add_child(go)
	else:
		var cont := Widgets.button("CONTINUE", continue_on)
		cont.name = "Continue"
		buttons.add_child(cont)
	if right != null:
		foot.free()
		buttons.size_flags_horizontal = Control.SIZE_SHRINK_END
		if d_top:
			# level with the title: CONTINUE's words on the title's baseline
			# (`D_BUTTONS_DROP`), the button's middle on RESOLVED's
			var drop := _dropped(buttons)
			drop.size_flags_horizontal = Control.SIZE_SHRINK_END
			right.add_child(drop)
			right.move_child(drop, 0)
		else:
			right.add_child(buttons)
	elif layout == &"card":
		# (narrow: the ledger on its line, the buttons under it; D's table
		# right-aligned over them)
		var brow := HBoxContainer.new()
		var sp2 := Control.new()
		sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		brow.add_child(sp2)
		if tab != null or prizes != null or d_top:
			# D: the table and the buttons one right-aligned column, the table at
			# least as wide as the buttons; E's plates over the table
			foot.free()
			var col := VBoxContainer.new()
			col.add_theme_constant_override("separation", 6)
			if prizes != null:
				prizes.size_flags_horizontal = Control.SIZE_SHRINK_END
				col.add_child(prizes)
			if tab != null:
				col.add_child(tab)
			buttons.size_flags_horizontal = Control.SIZE_SHRINK_END
			if d_top:
				_card_top(head, buttons)
			else:
				col.add_child(buttons)
			brow.add_child(col)
		else:
			_box.add_child(foot)
			brow.add_child(buttons)
		if d_top and tab == null:
			# D with none of the four stats moved: the buttons on the title's
			# line and nothing at the foot
			brow.free()
		else:
			_box.add_child(brow)
	else:
		foot.add_child(buttons)
		_box.add_child(foot)
	_choices = buttons
	OutcomeRow.hold(self)
	_fit_and_show()


## D's buttons in a box that stands them `D_BUTTONS_DROP` under the top.
static func _dropped(buttons: Control) -> MarginContainer:
	var drop := MarginContainer.new()
	drop.name = "ButtonsDrop"
	drop.add_theme_constant_override("margin_top", D_BUTTONS_DROP)
	for side in ["margin_left", "margin_right", "margin_bottom"]:
		drop.add_theme_constant_override(side, 0)
	drop.add_child(buttons)
	return drop


## D on the card: buttons on the title line, or their own line for a long name, so it never widens.
func _card_top(head: Control, buttons: Control) -> void:
	var top := HBoxContainer.new()
	top.name = "ResultTop"
	top.add_theme_constant_override("separation", 10)
	var at := head.get_index()
	_box.remove_child(head)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(head)
	# level with the title, as in the band (`D_BUTTONS_DROP`)
	var drop := _dropped(buttons)
	drop.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(drop)
	_box.add_child(top)
	_box.move_child(top, at)
	if top.get_combined_minimum_size().x <= CARD_W - 20.0:
		return
	drop.remove_child(buttons)
	drop.free()
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.move_child(sp, 0)
	top.add_child(buttons)
	top.remove_child(head)
	head.size_flags_horizontal = Control.SIZE_FILL
	_box.add_child(head)
	_box.move_child(head, at + 1)


## Starts once the band is down: on the press it threw the band away mid-drop.
## Why: docs/why/LocalEventDrawer.md#fight-start
func _fight() -> void:
	if fought:
		return
	fought = true
	if quiet:
		return
	if _tw != null and _tw.is_valid() and _tw.is_running() and _moving():
		await _tw.finished
	if is_inside_tree():
		# the creature the event's text set up, or a ship (`OptionResolve.take`)
		Router.start_ambush(StringName(out.get("foe", &"")))


## CONTINUE: it drops and you stay on LOCAL, the bar saying how it went.
func continue_on() -> void:
	if text != null and not text.done:
		text.skip()
		return
	_drop()


## The pile's one name, here and on LOCAL's bar and the map (it was REWARD here),
## in the ember ink over CONTINUE (Jon, Nov 9, stripped-down UI 6).
const LOOT_WORD := "SECTOR LOOT"

## SECTOR LOOT: the system's pile, your hold beside it (`TransferView`).
func open_reward() -> void:
	if _transfer != null or node == null:
		return
	var h := Run.sector_jetsam(node, false)
	if h == null:
		return
	_transfer = TransferView.new()
	screen.add_child(_transfer)
	# (the pile opens at your ship, in the room above this band)
	if visible and layout != &"card":
		_transfer.floor_g = UiRect.of(self).position.y
	Audio.play(&"wreck_open")
	_transfer.setup(h, node, func() -> void:
		_transfer.queue_free()
		_transfer = null
		if page == &"result":
			_result(), true, LOOT_WORD)


# --------------------------------------------------------------- words

func _tags(o: Dictionary) -> String:
	var bits: Array = []
	for t in o.get("tags", []):
		bits.append(String(t).to_upper())
	return " · ".join(bits)


## "THETA GALLOWS II · SWAMP WORLD · YOU ARE IN ORBIT".
func _place_line(i: int) -> String:
	var b := body_of(node, i)
	var L := SystemLayout.of(node)
	if b == SystemLayout.COMET and L.comet != null:
		return "%s · YOU ARE ON ITS PATH" % L.comet.name
	if b < 0 or b >= L.bodies.size():
		# On a star, named as the map names it. An option on no place reads as star A, as ever.
		return L.star_title(node, SystemLayout.STAR_B if b == SystemLayout.STAR_B else -1) + " · YOU ARE IN A CLOSE ORBIT"
	var body: SystemLayout.Body = L.bodies[b]
	var kind := Worlds.display_name(body.world) if body.world != &"" else \
		String({&"belt": "ASTEROID BELT", &"derelict": "DERELICT HULK", &"contact": "CONTACT", &"station": "STATION"}.get(body.kind, ""))
	var there := "ALONGSIDE" if body.kind in [&"belt", &"station", &"derelict", &"contact"] else "IN ORBIT"
	return "%s · %s · YOU ARE %s" % [body.name.to_upper(), kind, there]


## The others in option i's set that taking it would close.
func _rivals(i: int) -> Array:
	var g := StringName(OptionTable.by_id(node.options[i]).get("group", &""))
	var rv: Array = []
	if g == &"":
		return rv
	for j in node.options.size():
		if j == i or StringName(OptionTable.by_id(node.options[j]).get("group", &"")) != g:
			continue
		var k: StringName = EncounterDrawer.option_state(node, j).kind
		if k == &"open" or k == &"left":
			rv.append(j)
	return rv
