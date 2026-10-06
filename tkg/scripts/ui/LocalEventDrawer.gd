class_name LocalEventDrawer
extends Control

## EVENTS RESOLVE ON LOCAL (Jon picked drawer A, the low full-width band: "THIS
## IS NIIIICE. I like A low band."; scratchpad `local_role/notes.md` section 5).
##
## The sector map lists a system's events as cards and says one sentence of
## each; GO flies the ship there and the view zooms down into LOCAL, composed
## for that body (`SystemMapScreen._parked` -> `LocalSky`'s situation). Then
## this comes up with the event's whole text and its choices -- the same choice
## cards, odds, costs and readings the map's panel showed
## (`EncounterDrawer.choice_card`). Choosing resolves through `OptionResolve`,
## the one rule; the result comes up in the same place: the band word, YOU
## CHOSE, what happened, the four ledger rows, REWARD (the system's pile in
## `TransferView`) and CONTINUE. A fight it starts is THEY ARE FIRING, and then
## the fight itself, whose hand takes the band's place. NOT NOW drops it and the
## bar under the view says OPEN IT.
##
## THE ONLY PLACE A CHOICE IS TAKEN: the map's panel no longer resolves events.
## Co-op is unchanged -- `OptionResolve.take` asks the party first, as it did.
##
## THREE LAYOUTS, ONE SWITCH (`layout`), so Jon can pick from stills:
##   row     the low band, as tall as what it says (Jon: "almost too much empty
##           space in the drawer"), capped at the fight hand's height; the
##           choices a row of compact cards under the text
##   column  the same band, the choices a narrow column on the right
##   card    a small card that pops up in the middle of the play area (Jon: "What
##           about a small card pop in the middle?"), nudged off your ship and
##           the encounter's subject so the scene is still what you look at
## Everything else -- the flow, the rule, the words -- is the same in all three.
##
## THE TEXT ARRIVES LIKE A SIGNAL (`SignalText`); any click or key finishes it
## (and is spent doing so), and the choices fade in only once it has.
##
## The bar's half lives here too (`bar_line`, `can_reopen`), so `SectorScreen`
## only asks what to print and whether to offer OPEN IT.

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

static var layout: StringName = &"row"
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
	var L := SystemLayout.of(n)
	for bi in L.bodies.size():
		for bc in L.bodies[bi].beacons:
			if bc.opt == i:
				return bi
	return -2


## Whether the ship is parked where option i stands (the map leaves it there).
static func here_now(n: MapGen.MapNode, i: int) -> bool:
	var d: Dictionary = SystemMapScreen._parked.get(n.index, {})
	return d.is_empty() or int(d.get("at", -9)) == body_of(n, i)


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

## Put a drawer on LOCAL's screen, and open the event the map asked for. Not
## during a fight (the hand has the band), and not for another system.
static func attach(on: Control, fighting: bool) -> LocalEventDrawer:
	var d := LocalEventDrawer.new()
	d.screen = on
	d.node = Run.node_at()
	on.add_child(d)
	if not pending.is_empty():
		var want: Array = pending
		pending = []
		if not fighting and d.node != null and int(want[0]) == d.node.index:
			d._fade_in()
			d.open(int(want[1]))
	return d


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
	_tw = create_tween()
	_tw.tween_method(_place, 1.0, 0.0, LIFT_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _drop() -> void:
	page = &""
	_up = false
	if _tw != null:
		_tw.kill()
	var gone := func() -> void:
		visible = false
		changed.emit()
	if not _moving():
		_place(1.0)
		gone.call()
		return
	_tw = create_tween()
	if layout == &"card":
		_tw.tween_property(panel, "modulate:a", 0.0, POP_S * 0.8)
	else:
		_tw.tween_method(_place, 0.0, 1.0, LIFT_S * 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tw.tween_callback(gone)


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
	if _choices == null:
		return
	if not _moving():
		_choices.modulate.a = 1.0
		return
	var tw := _choices.create_tween()
	tw.tween_property(_choices, "modulate:a", 1.0, CHOICES_S)


## The card in the middle of the play area, nudged off your ship, any other hull
## and the encounter's subject (the reason the event came to LOCAL is to see it):
## the nearest place to the middle that covers none of them, or covers least.
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
	var at := get_global_rect().position
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

func _result() -> void:
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
	_box.add_child(head)
	var chose := "YOU CHOSE: " + String((choices[choice] as Dictionary).get("label", "")).to_upper() \
		if choice >= 0 and choice < choices.size() else ""
	if out.get("checked", false):
		chose += " · " + String(out.get("odds", ""))
	var cl := UITheme.body(chose, UITheme.COLD, UITheme.FS_SMALL)
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(cl)
	_box.add_child(_text_box(String(res.get("text", "")), UITheme.CHILL if ink == UITheme.COLD else ink))
	# THE LEDGER AS ONE ROW, the buttons at the end of it
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	for r in out.get("bill", []):
		foot.add_child(UITheme.body(String(r.name), UITheme.COLD, UITheme.FS_SMALL))
		var v := UITheme.body(String(r.text), r.tone as Color, UITheme.FS_SMALL)
		v.custom_minimum_size.x = 22
		foot.add_child(v)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	if out.get("stay", false):
		var again := Widgets.button("CHOOSE AGAIN", func() -> void: open(opt))
		again.name = "ChooseAgain"
		buttons.add_child(again)
	if OptionTable.pays_item(res) and not Run.dead:
		var claim := Widgets.button("REWARD", open_reward)
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
	if layout == &"card":
		# (narrow: the ledger on its line, the buttons under it)
		_box.add_child(foot)
		var brow := HBoxContainer.new()
		var sp2 := Control.new()
		sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		brow.add_child(sp2)
		brow.add_child(buttons)
		_box.add_child(brow)
	else:
		foot.add_child(buttons)
		_box.add_child(foot)
	_choices = buttons
	_fit_and_show()


## The fight the event started: the existing one, whose hand takes the band.
func _fight() -> void:
	fought = true
	if not quiet:
		Router.start_ambush()


## CONTINUE: it drops and you stay on LOCAL, the bar saying how it went.
func continue_on() -> void:
	if text != null and not text.done:
		text.skip()
		return
	_drop()


## REWARD: the system's pile, your hold beside it (`TransferView`).
func open_reward() -> void:
	if _transfer != null or node == null:
		return
	var h := Run.sector_jetsam(node, false)
	if h == null:
		return
	_transfer = TransferView.new()
	screen.add_child(_transfer)
	Audio.play(&"wreck_open")
	_transfer.setup(h, node, func() -> void:
		_transfer.queue_free()
		_transfer = null
		if page == &"result":
			_result(), true, "REWARD")


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
	if b < 0 or b >= L.bodies.size():
		return MapGen.star_name(node) + " · YOU ARE IN A CLOSE ORBIT"
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
