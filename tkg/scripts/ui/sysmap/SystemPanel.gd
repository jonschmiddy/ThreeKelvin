extends VBoxContainer

## THE SECTOR MAP'S PANEL, on the right of the map in the star chart's own type.
##
## TWO PAGES, NOT SIX (Jon: "It's not super clear right now to the user what the
## actual events are in a particular sector. There are also multiple different
## pages for the right panel ... It could be super simplified"; he picked B on
## the "Sector Panel Rethink" mockup). It had a sector page, a star page, a
## world page, an encounter page, a page each for DOCK and HARVEST, and a result
## page, and the list of beacons was printed on three of them. Now:
##   LIST   every event in the sector as a card: its title, its tag word in its
##          colour, where it is, and its first line -- or, once it is over, a
##          stamp saying how it ended and a line of what came of it. DOCK,
##          HARVEST and the custodian are cards with their button on them.
##          Clicking a world or the star on the map narrows the list to that
##          place, with its picture, its facts and FLY HERE on top; SHOW ALL
##          widens it again. There is no star page and no world page.
##   EVENT  one encounter: its place, whether a choice flies you there, its
##          text and its choices. Choosing keeps you on this page, which then
##          shows what you chose and how it went, and NEXT EVENT at the foot.
##          Walking away is a short LEFT ALONE: it is still open.
##
## THE PAIR IS SHOWN WHEN IT MATTERS (Jon: "hovering over an option would grey
## it out and would say WILL BE MADE UNAVAILABLE"). No divider and no warning
## line: pointing at a card greys its rival and says so top right; pointing at a
## choice that would take the event says what it would close; once taken, the
## rival is stamped UNAVAILABLE.
##
## THE STAMP (Jon picked treatment 1 of three): a finished card dims hard and
## wears a solid badge with a pixel mark -- a tick in its band's colour, a cross
## on grey for UNAVAILABLE, a figure on the partner colour with their name -- and
## LEFT ALONE is an outline badge on a card that stays bright, because it is
## still there to take. What each state means is `EncounterDrawer.option_state`.
##
## IN ORBIT, THE CHOICES (Jon: "you can either fly to a planet... get in its orbit,
## and the right panel updates with info on the planet, the picture of the
## planet, and the choices. OR you click on the choices and that moves you to the
## planet's orbit"). A place's page is its picture, its facts, whether you are in
## orbit of it, and every event there with its text and its choices. Until you
## are there they are LOCKED -- dimmed, but still clickable: a click flies you
## into orbit and takes the choice when you get there. The star's page is the
## same, with its own picture and the worlds that go round it.
##
## The screen owns the rules; this only builds what is shown and calls back.

const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")
const KeyGlyphS := preload("res://scripts/ui/sysmap/KeyGlyph.gd")
const SunViewS := preload("res://scripts/ui/sysmap/SunView.gd")
## A locked choice: dimmed this far, and still clickable.
const LOCKED_A := 0.55

## The chart's panel width, and the width its text wraps at.
const W := 236
const TEXT_W := 228
const DIM := Color("#55647a")
## A finished card's stripe and ground: dimmed hard, so the open ones are the
## brightest things in the list.
const SPENT := Color("#3a4654")
const DONE_BG := Color("#0c1119")
const DONE_EDGE := Color("#182029")

var screen
var _box: VBoxContainer
var _foot: HBoxContainer
var _scroll: ScrollContainer
var _portrait: Node2D = null
## Which page is up: &"list", &"event" or &"result".
var mode: StringName = &"list"
## The place the list is narrowed to: a body, -1 the star, -2 nowhere.
var filter: int = -2
## The option whose page is up.
var open_opt: int = -1
## The list's cards by key -- an option index, or &"harvest", &"dock",
## &"core" -- so pointing at a beacon on the map can light its card.
var _cards: Dictionary = {}
## Under the choices: what taking the pointed-at one would close.
var _conseq: RichTextLabel = null


func _init() -> void:
	add_theme_constant_override("separation", 4)
	custom_minimum_size = Vector2(W, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_box)
	_foot = HBoxContainer.new()
	_foot.add_theme_constant_override("separation", 4)
	add_child(_foot)


func _clear() -> void:
	Widgets.clear(_box)
	Widgets.clear(_foot)
	_portrait = null
	_cards = {}
	_conseq = null
	_scroll.scroll_vertical = 0


# ---------------------------------------------------------------- the chart's type
func _eyebrow(text: String, c: Color = UITheme.COLD) -> Label:
	var l := UITheme.body(text, c, UITheme.FS_SMALL)
	_box.add_child(l)
	return l


func _wrap(text: String, c: Color, sz: int, into: Container = null) -> Label:
	var l := UITheme.body(text, c, sz)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(TEXT_W, 0)
	(into if into != null else _box).add_child(l)
	return l


func _name(text: String, c: Color = UITheme.ICE) -> void:
	_wrap(text, c, UITheme.FS_HEAD)


func _class(text: String) -> void:
	if text != "":
		_wrap(text, UITheme.THEM, UITheme.FS_SMALL)


func _blurb(text: String, c: Color = UITheme.COLD) -> void:
	if text != "":
		_wrap(text, c, UITheme.FS_SMALL)


func _rule() -> void:
	_box.add_child(UITheme.hsep())


func _row(key: String, value: String, colour: Color = UITheme.CHILL) -> void:
	var row := HBoxContainer.new()
	row.add_child(UITheme.body(key, UITheme.COLD, UITheme.FS_SMALL))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	row.add_child(UITheme.body(value, colour, UITheme.FS_SMALL))
	_box.add_child(row)


func _gap(h := 4) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	_box.add_child(c)


## Words in more than one colour, wrapped: `[color=#..]` runs in the pixel face.
func _rich(bbcode: String, width: float = TEXT_W) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.custom_minimum_size = Vector2(width, 0)
	r.add_theme_font_override("normal_font", UITheme.pixel_font())
	r.add_theme_font_size_override("normal_font_size", UITheme.FS_SMALL)
	r.text = bbcode
	return r


static func _c(text: String, c: Color) -> String:
	return "[color=#%s]%s[/color]" % [c.to_html(false), text.replace("[", "[lb]")]


## A button at the foot, the chart's JUMP size. It clips its words rather than
## widening the panel: a long NEXT: title used to push the map frame narrower.
func _act(text: String, on: Callable, click := true) -> Button:
	var b := Widgets.button(text, on, click)
	b.custom_minimum_size = Vector2(0, 24)
	b.clip_text = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_foot.add_child(b)
	return b


## A small button inside a card or a page: DOCK, HARVEST, FLY HERE.
func _small(text: String, on: Callable, off := false) -> Button:
	var b := Widgets.button(text, on)
	b.disabled = off
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


## A flat link in the eyebrow's type: < ALL EVENTS, SHOW ALL, < and >.
func _link(text: String, on: Callable, tip := "") -> Button:
	var b := Button.new()
	Widgets.wear_pointer(b)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.tooltip_text = tip
	b.add_theme_font_size_override("font_size", UITheme.FS_SMALL)
	b.add_theme_color_override("font_color", UITheme.COLD)
	b.add_theme_color_override("font_hover_color", UITheme.FLARE)
	b.pressed.connect(on)
	return b


func _spacer() -> Control:
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sp


# ---------------------------------------------------------------- what is in the sector
## Every event in the sector, as [body, beacon], in orbit order; the pulsar's
## own on the star (beacon null).
func _events() -> Array:
	var L: SystemLayout = screen.view.layout
	var out: Array = []
	for bi in L.bodies.size():
		for bc in L.bodies[bi].beacons:
			out.append([bi, bc])
	if screen.view.node.type == MapGen.NodeType.PULSAR:
		out.append([-1, null])
	return out


## The encounters alone, as option indices in list order: what < and > step.
func _encounters() -> Array:
	var out: Array = []
	for pair in _events():
		if pair[1] != null and pair[1].opt >= 0:
			out.append(pair[1].opt)
	return out


func _key(bc) -> Variant:
	if bc == null:
		return &"harvest"
	if bc.dock:
		return &"dock"
	if bc.core:
		return &"core"
	return bc.opt


func _body_of_opt(i: int) -> int:
	var L: SystemLayout = screen.view.layout
	for bi in L.bodies.size():
		for bc in L.bodies[bi].beacons:
			if bc.opt == i:
				return bi
	return -1


func _place_name(body: int) -> String:
	var v = screen.view
	return v.star_name() if body < 0 else v.layout.bodies[body].name


func _place_kind(body: int) -> String:
	var v = screen.view
	return v.star_class() if body < 0 else v.body_kind(v.layout.bodies[body])


## In orbit of it (or alongside it, or in a close orbit of the star): its events
## are open.
func _ship_at(body: int) -> bool:
	return screen.ship_reached(body)


## What being there is called at this place.
func _there_word(body: int) -> String:
	if body < 0:
		return "IN A CLOSE ORBIT"
	var k: StringName = screen.view.layout.bodies[body].kind
	return "ALONGSIDE" if k == &"belt" or k == &"station" or k == &"derelict" or k == &"contact" else "IN ORBIT"


## The line a locked page carries over its choices: a choice flies you there,
## but only out of an orbit (`ShipFlight.can_fly`).
const LOCKED_LINE := "LOCKED UNTIL YOU ARE THERE · A CHOICE FLIES YOU THERE FIRST"
const WAIT_LINE := "LOCKED UNTIL YOU ARE THERE · AVAILABLE ONCE YOU ARE IN AN ORBIT"
## on the way to it already
const COMING_LINE := "LOCKED UNTIL YOU ARE THERE · AVAILABLE ON ARRIVAL"


func _can_go() -> bool:
	return screen.flight != null and screen.flight.can_fly()


func _locked_line(body: int = -9) -> String:
	if _can_go():
		return LOCKED_LINE
	return COMING_LINE if _heading_to(body) else WAIT_LINE


## Whether the flight under way is taking the ship to `body`.
func _heading_to(body: int) -> bool:
	return body >= -1 and screen.flight != null and screen.flight.heading_to() == body


## An event's page drawn again as it stands.
func open_page(i: int) -> void:
	open_opt = i
	_event_page({})


func _state(i: int) -> Dictionary:
	return EncounterDrawer.option_state(screen.view.node, i)


func _is_open(i: int) -> bool:
	var k: StringName = _state(i).kind
	return k == &"open" or k == &"left"


## The others in option i's set that taking it would close.
func _rivals(i: int) -> Array:
	var n: MapGen.MapNode = screen.view.node
	var g := StringName(OptionTable.by_id(n.options[i]).get("group", &""))
	var out: Array = []
	if g == &"":
		return out
	for j in n.options.size():
		if j != i and StringName(OptionTable.by_id(n.options[j]).get("group", &"")) == g and _is_open(j):
			out.append(j)
	return out


func _title(i: int) -> String:
	return String(OptionTable.by_id(screen.view.node.options[i]).get("title", "")).to_upper()


## The tag words, the lead one in its colour: "FIGHT · HAZARD".
func _tags_bb(o: Dictionary) -> String:
	var lead := EncounterDrawer.lead_tag(o)
	var parts: Array = []
	if lead != &"":
		parts.append(_c(String(lead).to_upper(), EncounterDrawer.tag_colour(o)))
	for t in EncounterDrawer.TAG_ORDER:
		if t != lead and (o.get("tags", []) as Array).has(String(t)):
			parts.append(_c(String(t).to_upper(), UITheme.COLD))
	return _c(" · ", UITheme.COLD).join(parts)


# ---------------------------------------------------------------- the stamp
## The badge on a card that is not simply open: solid in its band's colour with
## a tick, grey with a cross for UNAVAILABLE, the partner colour with a figure,
## and an outline with an arrow back for LEFT ALONE.
func _badge(st: Dictionary) -> Control:
	var ink: Color = st.ink
	var bg := ink
	var edge := ink
	var fg := UITheme.VOID
	var mark := &"tick"
	match st.kind:
		&"gone":
			bg = Color("#2a3442")
			edge = DIM
			fg = UITheme.CHILL
			mark = &"cross"
		&"who":
			mark = &"who"
		&"left":
			bg = Color(0, 0, 0, 0)
			edge = UITheme.CHILL
			fg = UITheme.CHILL
			mark = &"back"
	var p := PanelContainer.new()
	var sb := UITheme.flat(bg, edge, 0, 0, 3)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var g: Control = KeyGlyphS.new()
	g.set("glyph", mark)
	g.set("colour", fg)
	g.call("small")
	row.add_child(g)
	row.add_child(UITheme.body(String(st.word), fg, UITheme.FS_SMALL))
	return p


## The line a card says under its tags, by its state.
func _card_line(i: int, st: Dictionary, o: Dictionary) -> String:
	var n: MapGen.MapNode = screen.view.node
	var hook := EncounterDrawer.first_sentence(String(o.get("body", "")))
	match st.kind:
		&"left":
			var w := String(n.left.get(i, ""))
			return _c("STILL OPEN · ", UITheme.ICE) + _c(w if w != "" else hook, UITheme.COLD)
		&"band":
			# what it came to, off the node (`MapNode.said`); a save from before
			# the node kept it has only the band, and shows the first line
			var said: Array = n.said.get(i, [])
			if said.size() < 2:
				return _c(hook, UITheme.COLD)
			var moved := String(said[0])
			return (_c(moved + " · ", UITheme.CHILL) if moved != "" else "") + _c(String(said[1]), UITheme.COLD)
		&"gone":
			if String(st.by) == "":
				return _c("Closed when the other in its set was taken.", UITheme.COLD)
			var who := "you" if String(st.by_who) == "" else String(st.by_who)
			return _c("Closed when %s took %s." % [who, String(st.by).to_upper()], UITheme.COLD)
		&"who":
			return _c("%s got here first." % String(st.who), UITheme.COLD)
	return _c(hook, UITheme.CHILL)


# ---------------------------------------------------------------- LIST
func show_system() -> void:
	filter = -2
	_list()


## A world or the star clicked on the map: the list, narrowed to it.
func show_body(i: int) -> void:
	filter = i
	_list()


func _list() -> void:
	_clear()
	mode = &"list"
	if filter >= 0:
		_place_head(filter)
	else:
		# ONE PAGE FOR THE SECTOR AND ITS STAR (Jon: "why are there two pages
		# here?"): the star or empty space clicked, it is the same page
		_star_head()
		# A HULL ON OFFER, the one thing the sector's salvage rail still holds
		# (`SectorScreen._refresh_salvage`): the same row, the same DECIDE LATER.
		if Run.found_hull != null and not Run.salvage_hushed(screen.bag_here()):
			_eyebrow("A HULL, IF YOU WANT IT", UITheme.EMBER)
			_box.add_child(Widgets.hull_row(Run.found_hull, "TRANSFER", 0, func(what: String, h: Variant) -> void: screen.on_hull(what, h)))
			var later := Widgets.button("DECIDE LATER", func() -> void: screen.hush_hull())
			later.tooltip_text = Widgets.tip("Closes this. The hull stays on offer for the rest of the run.")
			_box.add_child(later)
			_gap()
	# THE STAR HOLDS THE WHOLE SECTOR (Jon: "this panel should also have all
	# the BEACONS HERE for the sector"), so it narrows nothing.
	var all := _events()
	var shown: Array = all if filter < 0 else all.filter(func(p: Array) -> bool: return p[0] == filter)
	var open := 0
	for pair in all:
		if _pair_open(pair):
			open += 1
	if all.is_empty():
		_eyebrow("NOTHING OUT HERE WANTS YOU")
	elif filter >= 0:
		_eyebrow("ON %s · %d EVENT%s" % [_place_name(filter), shown.size(), "" if shown.size() == 1 else "S"])
	else:
		_eyebrow("EVENTS · %d OPEN OF %d" % [open, all.size()])
	for pair in shown:
		if filter >= 0 and pair[1] != null and pair[1].opt >= 0 and _is_open(pair[1].opt):
			_place_event(pair[0], pair[1].opt)
		else:
			_box.add_child(_card(pair[0], pair[1]))
	if filter >= 0 and shown.is_empty() and not all.is_empty():
		_eyebrow("NOTHING HERE WANTS YOU", DIM)
	if filter < 0:
		_satellites()
	# SECTOR LOOT ONLY WHEN THERE IS SOME (Jon: "Why does the first sector have a
	# SECTOR LOOT button? I can click it, but it doesn't do anything"): the floor
	# of jettisoned things, as the sector screen counts it; with nothing on it
	# there is no button, since only pressable things look pressable
	var n_loot: MapGen.MapNode = screen.view.node
	if Run.jetsam_left(n_loot, Run.sector_jetsam(n_loot, false)) > 0:
		_act("SECTOR LOOT", func() -> void: screen.open_sector_loot())
	_act("PLOT NEXT JUMP", func() -> void: screen.plot_next_jump(), false)


func _pair_open(pair: Array) -> bool:
	var bc = pair[1]
	var n: MapGen.MapNode = screen.view.node
	if bc == null or bc.core:
		return not (n.cleared or n.fled)
	if bc.dock:
		return true
	return _is_open(bc.opt)


## ONE OPEN EVENT ON ITS PLACE'S PAGE: its tags, its title, its text and its
## choices -- live while you are there, dimmed and LOCKED until you are (a
## click still takes it, flying you there first).
func _place_event(body: int, i: int) -> void:
	var n: MapGen.MapNode = screen.view.node
	var o := OptionTable.by_id(n.options[i])
	_gap(2)
	_box.add_child(_rich(_tags_bb(o)))
	_wrap(String(o.get("title", "")).to_upper(), EncounterDrawer.tag_colour(o).lerp(UITheme.ICE, 0.5), UITheme.FS_SMALL)
	var here := _ship_at(body)
	_blurb(String(o.get("body", "")), UITheme.CHILL if here else DIM)
	var choices: Array = o.get("choices", [])
	for j in choices.size():
		var card := EncounterDrawer.choice_card(n, i, j, choices[j], o, func(ii: int, jj: int) -> void: screen.take_choice(ii, jj))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not here:
			card.modulate.a = LOCKED_A
		_box.add_child(card)


## THE SECTOR'S PAGE, WHICH IS THE STAR'S: its picture, its name and class, the
## sector's place line and the star's facts, and the way into its close orbit;
## locked only when the star has an event of its own (the pulsar's harvest).
func _star_head() -> void:
	var v = screen.view
	_eyebrow("SECTOR")
	if v.kind in ["ORDINARY", "RED", "BLUE"]:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(TEXT_W, 84)
		holder.clip_contents = true
		_box.add_child(holder)
		var sv: Node2D = SunViewS.new()
		sv.position = Vector2(TEXT_W / 2, 42)
		holder.add_child(sv)
		sv.call("setup", v.kind, v.node.index, 22.0)
		_portrait = sv
	_name(v.star_name())
	_class(v.star_class())
	_blurb(MapGen.place_line(v.node))
	var sf: Dictionary = SystemViewS.STAR_FACTS[v.kind]
	_row("CLASS", sf.cls)
	_row("SURFACE", sf.temp)
	_row("MASS", sf.mass)
	_row("RADIUS", sf.radius)
	# THE WAY INTO ITS CLOSE ORBIT, always (Jon: "when I click on nothing, the
	# star is the focus of the panel, but there is no fly here"); locked only
	# when the star has an event
	_way_there(-1)
	_rule()


## The worlds that go round the star, each a link to its page.
func _satellites() -> void:
	var v = screen.view
	var L: SystemLayout = v.layout
	if L.bodies.is_empty():
		return
	_rule()
	_eyebrow("SATELLITES · %d" % L.bodies.size())
	for bi in L.bodies.size():
		var bd: SystemLayout.Body = L.bodies[bi]
		var row := HBoxContainer.new()
		row.add_child(_link(bd.name, func() -> void: screen.select_body(bi)))
		row.add_child(_spacer())
		row.add_child(UITheme.body(v.body_kind(bd), UITheme.COLD, UITheme.FS_SMALL))
		_box.add_child(row)


## Whether a place has any event of its own (the star's is the pulsar's harvest).
func _has_events(body: int) -> bool:
	for pair in _events():
		if pair[0] == body:
			return true
	return false


## THE WAY THERE: in orbit (or alongside) a place's events are open; until then
## they are locked, and FLY HERE (or any choice) takes you there.
func _way_there(i: int) -> void:
	var go := HBoxContainer.new()
	# WHERE FLY HERE GOES, GREYED (Jon: "have ON YOUR WAY and IN ORBIT be a
	# grayed-out button on the right side")
	if _ship_at(i):
		go.add_child(_spacer())
		go.add_child(_small(_there_word(i), func() -> void: pass, true))
	else:
		go.add_child(_spacer())
		if _can_go():
			go.add_child(_small("FLY HERE", func() -> void: screen.fly_to_body(i)))
		elif _heading_to(i):
			go.add_child(_small("ON YOUR WAY", func() -> void: pass, true))
		else:
			go.add_child(_small("FLY HERE ONCE IN ORBIT", func() -> void: pass, true))
	_box.add_child(go)
	if not _ship_at(i) and _has_events(i):
		_blurb(_locked_line(i), UITheme.COLD)


## The place the list is narrowed to: its picture, its name and kind, its facts,
## and the way there. Where the world pages used to be.
func _place_head(i: int) -> void:
	var v = screen.view
	var L: SystemLayout = v.layout
	var b: SystemLayout.Body = null if i < 0 else L.bodies[i]
	var top := HBoxContainer.new()
	top.add_child(UITheme.body("STAR" if b == null else ("WORLD" if b.world != &"" else String(b.kind).to_upper()), UITheme.COLD, UITheme.FS_SMALL))
	top.add_child(_spacer())
	top.add_child(_link("SHOW ALL ×", func() -> void: screen.panel_back(), "Every event in the sector"))
	_box.add_child(top)
	if b != null and b.world != &"":
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(TEXT_W, 84)
		_box.add_child(holder)
		var pv: Node2D = Worlds.view_for(b.world)
		var bv: Node2D = v._views.get(b.index)
		var ringed: bool = bv != null and (bv.get("spec") as Dictionary).get("ring", false)
		pv.call("set_world", b.world, b.seed, 22.0 if ringed else 34.0)
		# IN 2x2 BLOCKS, as the world is on the map (Jon: "this should be 2x2 yeah?")
		pv.call("set_cell", 2)
		pv.position = Vector2(TEXT_W / 2, 42)
		holder.add_child(pv)
		_portrait = pv
	elif b == null and v.kind in ["ORDINARY", "RED", "BLUE"]:
		# THE STAR'S OWN PICTURE (Jon: "the star should show some info when it's
		# the focus of the right panel"): the sector map's sun, at the panel's size
		var holder2 := Control.new()
		holder2.custom_minimum_size = Vector2(TEXT_W, 84)
		holder2.clip_contents = true
		_box.add_child(holder2)
		var sv: Node2D = SunViewS.new()
		sv.position = Vector2(TEXT_W / 2, 42)
		holder2.add_child(sv)
		sv.call("setup", v.kind, v.node.index, 22.0)
		_portrait = sv
	_name(_place_name(i))
	_class(_place_kind(i))
	if b != null:
		for f in v.facts(b):
			if String(f[0]) != "TYPE" and String(f[0]) != "BEACONS":
				_row(f[0], f[1])
	else:
		var sf: Dictionary = SystemViewS.STAR_FACTS[v.kind]
		_row("CLASS", sf.cls)
		_row("SURFACE", sf.temp)
		_row("MASS", sf.mass)
		_row("RADIUS", sf.radius)
	_way_there(i)
	_rule()


func _process(_d: float) -> void:
	if _portrait != null and is_instance_valid(_portrait):
		if _portrait.has_method("set_world"):
			_portrait.call("step", screen.view.t, Vector3(-0.83, -0.31, 0.47))
		else:
			_portrait.call("step", screen.view.t)


# ---------------------------------------------------------------- a card
func _card(body: int, bc) -> Control:
	var v = screen.view
	var n: MapGen.MapNode = v.node
	var key: Variant = _key(bc)
	var card := EventCard.new()
	card.hover_cb = func(on: bool) -> void: _on_card_hover(key, body, bc, on)
	var where := _place_name(body)
	if bc == null or bc.dock or bc.core:
		# THE ACTIONS ARE CARDS WITH THEIR BUTTON ON THEM. They each had a page
		# of their own holding one sentence and that button.
		var words: Array
		if bc == null:
			words = ["HARVEST THE BEAM", "NEUTRON STAR", "The pulsar's beam sweeps the system once a second. Hold the ship in it and the hull drinks heat.", "HARVESTED" if n.cleared else "HARVEST", UITheme.TRACTOR, n.cleared]
		elif bc.dock:
			words = ["DOCK", "STATION", "A station rides this orbit. Its berths are open and its decks are lit.", "DOCK", UITheme.ICE, false]
		else:
			words = ["THE CUSTODIAN", "CONTACT", "Something holds station at the edge of the disc. It has been waiting a long time, and it has seen you.", "ENGAGE", UITheme.BAD, n.cleared or n.fled]
		var btn := _small(words[3], func() -> void: screen.take_action(bc), words[5])
		card.build(words[0], UITheme.ICE, btn, _c(words[1], words[4]), where, _ship_at(body), _c(words[2], UITheme.CHILL), words[4])
		_cards[key] = card
		return card
	var i: int = bc.opt
	var o: Dictionary = screen.overlay.option_of(bc)
	var st := _state(i)
	var done: bool = st.kind != &"open" and st.kind != &"left"
	var right: Control = _badge(st) if st.kind != &"open" else null
	card.build(String(o.get("title", "")).to_upper(), DIM if done else UITheme.ICE, right, _tags_bb(o), where,
		_ship_at(body) and not done, _card_line(i, st, o), SPENT if done else EncounterDrawer.tag_colour(o))
	card.finished = done
	card.press = func() -> void: screen.open_beacon(body, bc)
	Widgets.wear_pointer(card)
	card.dress()
	_cards[key] = card
	return card


## A card pointed at: its rivals grey and say what taking it would do, and its
## beacon lights on the map.
func _on_card_hover(key: Variant, body: int, bc, on: bool) -> void:
	_doom_rivals(key, on)
	screen.card_hover(body, bc, on)


func _doom_rivals(key: Variant, on: bool) -> void:
	if typeof(key) != TYPE_INT or not _is_open(int(key)):
		return
	for j in _rivals(int(key)):
		var c: EventCard = _cards.get(j)
		if c != null:
			c.set_doomed(on)


## The map pointing at a beacon lights its card the same way.
func light(bc, on: bool) -> void:
	if mode != &"list":
		return
	var key: Variant = _key(bc)
	var c: EventCard = _cards.get(key)
	if c != null:
		c.set_hot(on)
	_doom_rivals(key, on)


# ---------------------------------------------------------------- EVENT
func show_beacon(body: int, bc) -> void:
	if bc == null or bc.dock or bc.core:
		# an action's card is its page: the list, narrowed to where it is
		show_body(body)
		return
	open_opt = bc.opt
	_event_page({})


func show_result(i: int, out: Dictionary) -> void:
	open_opt = i
	_event_page(out)


## < and > and the arrow keys: the next encounter round the list.
func step(d: int) -> void:
	var encs := _encounters()
	if encs.is_empty():
		return
	var at := encs.find(open_opt) if mode != &"list" else (-1 if d > 0 else 0)
	screen.open_option(int(encs[posmod(at + d, encs.size())]))


func _event_page(out: Dictionary) -> void:
	_clear()
	mode = &"event" if out.is_empty() else &"result"
	var v = screen.view
	var n: MapGen.MapNode = v.node
	var i := open_opt
	var o := OptionTable.by_id(n.options[i])
	var body := _body_of_opt(i)
	var encs := _encounters()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 2)
	top.add_child(_link("< ALL EVENTS", func() -> void: screen.panel_back()))
	top.add_child(_spacer())
	top.add_child(UITheme.body("%d OF %d" % [encs.find(i) + 1, encs.size()], UITheme.COLD, UITheme.FS_SMALL))
	top.add_child(_link("<", func() -> void: step(-1), "Previous event (%s)" % Keys.describe(&"event_prev")))
	top.add_child(_link(">", func() -> void: step(1), "Next event (%s)" % Keys.describe(&"event_next")))
	_box.add_child(top)
	_box.add_child(_rich(_tags_bb(o)))
	_name(String(o.get("title", "")).to_upper(), EncounterDrawer.tag_colour(o).lerp(UITheme.ICE, 0.5))
	_class("%s  ·  %s" % [_place_name(body), _place_kind(body)])
	if not out.is_empty():
		_result(i, out)
		return
	var st := _state(i)
	if st.kind == &"open" or st.kind == &"left":
		# THE TRIP COMES WITH THE CHOICE, and says so before you make it
		if _ship_at(body):
			_eyebrow("YOU ARE " + _there_word(body), UITheme.FLARE)
		else:
			_blurb(_locked_line(body), UITheme.COLD)
		if st.kind == &"left":
			_blurb("You walked away from this. It is still open.", UITheme.CHILL)
		_rule()
		_blurb(String(o.get("body", "")), UITheme.CHILL)
		_rule()
		var rivals := _rivals(i)
		var names := ", ".join(rivals.map(func(j: int) -> String: return _title(j)))
		var choices: Array = o.get("choices", [])
		for j in choices.size():
			var c: Dictionary = choices[j]
			var card := EncounterDrawer.choice_card(n, i, j, c, o, func(ii: int, jj: int) -> void: screen.take_choice(ii, jj))
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if not _ship_at(body):
				card.modulate.a = LOCKED_A
			_box.add_child(card)
			# WHAT IT WOULD CLOSE, said only while you point at a choice that
			# takes the event. Walking away closes nothing, so it says nothing.
			if not rivals.is_empty() and not bool(c.get("stay", false)) and OptionResolve.affordable(c):
				card.mouse_entered.connect(func() -> void: hover_choice(names))
				card.mouse_exited.connect(func() -> void: hover_choice(""))
		_conseq = _rich("")
		_conseq.custom_minimum_size = Vector2(TEXT_W, 11)
		_box.add_child(_conseq)
	else:
		var row := HBoxContainer.new()
		row.add_child(_badge(st))
		_box.add_child(row)
		_box.add_child(_rich(_card_line(i, st, o)))
		_rule()
		_blurb(String(o.get("body", "")), DIM)
	_act("ALL EVENTS", func() -> void: screen.panel_back())


## The line under the choices: "WILL MAKE THE QUEUE UNAVAILABLE", or nothing.
func hover_choice(names: String) -> void:
	if _conseq == null:
		return
	_conseq.text = "" if names == "" else _c("WILL MAKE ", UITheme.WARN) + _c(names, DIM) + _c(" UNAVAILABLE", UITheme.WARN)


# ---------------------------------------------------------------- RESULT
## How it went, on the event's own page: what you chose, the band, the bet, the
## trip, what it said and what it cost; then REWARD if it paid something, and
## the next open event. Walking away is short: it is still open.
func _result(i: int, out: Dictionary) -> void:
	var v = screen.view
	var n: MapGen.MapNode = v.node
	var o := OptionTable.by_id(n.options[i])
	var choices: Array = o.get("choices", [])
	var j: int = screen._res_choice
	if j >= 0 and j < choices.size():
		_blurb("YOU CHOSE: " + String((choices[j] as Dictionary).get("label", "")).to_upper())
	var said := String((out.res as Dictionary).get("text", ""))
	if out.stay:
		_name("LEFT ALONE", UITheme.CHILL)
		_eyebrow("STILL OPEN. NOTHING WAS SPENT.", UITheme.ICE)
		_blurb(said, UITheme.HOT)
		_act("ALL EVENTS", func() -> void: screen.panel_back())
		_act("CHOOSE AGAIN", func() -> void: screen.open_option(i))
		return
	var word := SkillCheck.band_name(out.band) if out.checked else "RESOLVED"
	var ink: Color = SkillCheck.band_colour(out.band) if out.checked else UITheme.CHILL
	_name(word, ink)
	if out.checked:
		_eyebrow(String(out.odds))
	if screen._res_flew:
		_eyebrow("YOUR SHIP FLEW %s FIRST" % ("ALONGSIDE" if _there_word(_body_of_opt(i)) == "ALONGSIDE" else "INTO ORBIT"), UITheme.FLARE)
	_blurb(said, UITheme.HOT)
	if not (out.bill as Array).is_empty():
		_rule()
		for r in out.bill:
			_row(String(r.name), String(r.text), r.tone as Color)
	if OptionTable.pays_item(out.res) and not Run.dead:
		var left := Run.jetsam_left(n, Run.sector_jetsam(n, false))
		var claim := _act("REWARD", func() -> void: screen.open_prize())
		claim.disabled = left <= 0
	var nx := _next_open(i)
	if nx >= 0:
		_act("NEXT: " + _title(nx), func() -> void: screen.open_option(nx))
	else:
		_act("ALL EVENTS", func() -> void: screen.panel_back())


## The next encounter round the list still open after option i, or -1.
func _next_open(i: int) -> int:
	var encs := _encounters()
	var at := encs.find(i)
	for k in range(1, encs.size()):
		var j: int = encs[posmod(at + k, encs.size())]
		if _is_open(j):
			return j
	return -1


# ---------------------------------------------------------------- the card itself
## ONE EVENT ON THE LIST: a stripe in its tag's colour, its title with its stamp
## top right, its tags and where it is, and one line. Pointed at, its rivals
## grey (`set_doomed`); finished, it dims hard so the open ones lead.
class EventCard extends PanelContainer:
	var press: Callable = Callable()
	var hover_cb: Callable = Callable()
	var finished := false
	var doomed := false
	var hot := false
	var stripe_col := UITheme.LINE
	var _stripe: ColorRect
	var _fade: Array[Control] = []
	var _right: Control = null
	var _doom: Label

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

	func build(title: String, title_c: Color, right: Control, tags_bb: String, where: String,
			here: bool, line_bb: String, stripe: Color) -> void:
		stripe_col = stripe
		var lane := HBoxContainer.new()
		lane.add_theme_constant_override("separation", 0)
		lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lane)
		_stripe = ColorRect.new()
		_stripe.custom_minimum_size = Vector2(2, 0)
		_stripe.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lane.add_child(_stripe)
		var pad := Widgets.pad(null, 6, 4)
		pad.add_theme_constant_override("margin_left", 7)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lane.add_child(pad)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_child(col)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 4)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(top)
		var t := UITheme.body(title, title_c, UITheme.FS_SMALL)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.clip_text = true
		top.add_child(t)
		_fade.append(t)
		if right != null:
			_right = right
			top.add_child(right)
		_doom = UITheme.body("WILL BE MADE UNAVAILABLE", UITheme.WARN, UITheme.FS_SMALL)
		_doom.visible = false
		top.add_child(_doom)
		var mid := HBoxContainer.new()
		mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(mid)
		var tags := _mk_rich(tags_bb)
		tags.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tags.custom_minimum_size = Vector2(0, 0)
		tags.autowrap_mode = TextServer.AUTOWRAP_OFF
		mid.add_child(tags)
		if here:
			mid.add_child(UITheme.body("YOU · ", UITheme.FLARE, UITheme.FS_SMALL))
		mid.add_child(UITheme.body(where, UITheme.COLD, UITheme.FS_SMALL))
		_fade.append(mid)
		var line := _mk_rich(line_bb)
		line.custom_minimum_size = Vector2(210, 0)
		col.add_child(line)
		_fade.append(line)
		dress()

	static func _mk_rich(bb: String) -> RichTextLabel:
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.fit_content = true
		r.scroll_active = false
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_theme_font_override("normal_font", UITheme.pixel_font())
		r.add_theme_font_size_override("normal_font_size", UITheme.FS_SMALL)
		r.text = bb
		return r

	func dress() -> void:
		var bg := UITheme.PANEL2
		var edge := UITheme.LINE
		if finished:
			bg = DONE_BG
			edge = DONE_EDGE
		if doomed:
			bg = UITheme.PANEL
			edge = Color("#1a2230")
		elif hot:
			bg = (DONE_BG if finished else UITheme.PANEL2).lightened(0.06)
			edge = UITheme.COLD
		add_theme_stylebox_override("panel", UITheme.flat(bg, edge, 0, 0, 0))
		if _stripe != null:
			_stripe.color = SPENT if doomed else stripe_col
		for c in _fade:
			c.modulate.a = 0.4 if doomed else (0.5 if finished else 1.0)
		if _right != null:
			_right.visible = not doomed
		if _doom != null:
			_doom.visible = doomed

	func set_doomed(on: bool) -> void:
		doomed = on
		dress()

	func set_hot(on: bool) -> void:
		hot = on
		dress()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER:
			set_hot(true)
			if hover_cb.is_valid():
				hover_cb.call(true)
		elif what == NOTIFICATION_MOUSE_EXIT:
			set_hot(false)
			if hover_cb.is_valid():
				hover_cb.call(false)

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if press.is_valid():
			press.call()
			accept_event()
