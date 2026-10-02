extends VBoxContainer

## THE SECTOR MAP'S PANEL, on the right of the map in the star chart's own type
## (Jon: "style the system page like the starchart page"): an eyebrow, the name
## large, a class line in orange, a paragraph, a rule, key and value rows, lists
## with a glyph a row, and the way on at the foot. Its states:
##   SECTOR  nothing selected: the system, its star and bodies, its beacons as
##           a list (the readable index, and the keyboard's way in), SECTOR
##           LOOT and PLOT NEXT JUMP.
##   BODY    a world, the star, a belt, a station: its picture, its facts, and
##           any beacons on it. The star lists its satellites (Jon: "when the
##           star is clicked, it should show its satellites").
##   BEACON  an encounter: its tags, title, the body it is on, its full text and
##           its choices with their odds, costs or contact reading -- the
##           sector drawer's own choice plates.
##   RESULT  how it went: the band, the bet you took, what it said, what it
##           cost, REWARD if it paid something, CONTINUE.
##   ACTION  the station's DOCK, the pulsar's HARVEST, the core's custodian.
## The screen owns the rules; this only builds what is shown and calls back.

const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")
const KeyGlyphS := preload("res://scripts/ui/sysmap/KeyGlyph.gd")

## The chart's panel width, and the width its text wraps at.
const W := 236
const TEXT_W := 228
const DIM := Color("#55647a")

var screen
var _box: VBoxContainer
var _foot: HBoxContainer
var _portrait: Node2D = null


func _init() -> void:
	add_theme_constant_override("separation", 4)
	custom_minimum_size = Vector2(W, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(sc)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_box)
	_foot = HBoxContainer.new()
	_foot.add_theme_constant_override("separation", 4)
	add_child(_foot)


func _clear() -> void:
	Widgets.clear(_box)
	Widgets.clear(_foot)
	_portrait = null


# ---------------------------------------------------------------- the chart's type
func _eyebrow(text: String, c: Color = UITheme.COLD) -> void:
	_box.add_child(UITheme.body(text, c, UITheme.FS_SMALL))


## The way back to the sector, where the chart has its eyebrow.
func _back(eyebrow: String, step := false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	_box.add_child(row)
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Widgets.wear_pointer(b)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.text = "< SECTOR  ·  " + eyebrow
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", UITheme.FS_SMALL)
	b.add_theme_color_override("font_color", UITheme.COLD)
	b.add_theme_color_override("font_hover_color", UITheme.FLARE)
	b.pressed.connect(func() -> void: screen.panel_back())
	row.add_child(b)
	# FROM WORLD TO WORLD (Jon: "it's unclear how to jump from planet to
	# planet"): the star and each body in orbit order, round and round; the
	# arrow keys do the same
	if step:
		for d in [-1, 1]:
			var a := Button.new()
			Widgets.wear_pointer(a)
			a.flat = true
			a.focus_mode = Control.FOCUS_NONE
			a.text = "<" if d < 0 else ">"
			a.tooltip_text = "Previous body (left arrow)" if d < 0 else "Next body (right arrow)"
			a.add_theme_font_size_override("font_size", UITheme.FS_SMALL)
			a.add_theme_color_override("font_color", UITheme.ICE)
			a.add_theme_color_override("font_hover_color", UITheme.FLARE)
			a.custom_minimum_size = Vector2(16, 0)
			a.pressed.connect(func() -> void: screen.step_body(d))
			row.add_child(a)


func _wrap(text: String, c: Color, sz: int) -> Label:
	var l := UITheme.body(text, c, sz)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(TEXT_W, 0)
	_box.add_child(l)
	return l


func _name(text: String, c: Color = UITheme.ICE) -> void:
	_wrap(text, c, UITheme.FS_HEAD)


func _class(text: String) -> void:
	if text != "":
		_wrap(text, UITheme.THEM, UITheme.FS_SMALL)


func _blurb(text: String) -> void:
	if text != "":
		_wrap(text, UITheme.COLD, UITheme.FS_SMALL)


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


func _gap() -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 4)
	_box.add_child(c)


## A list row like the chart's IN RANGE list: a glyph, a name, and on the right
## whatever is worth knowing at a glance. Pressing it does `act`.
func _list_row(glyph: StringName, colour: Color, label: String, label_c: Color,
		right: String, right_c: Color, act: Callable) -> void:
	var b := Button.new()
	Widgets.wear_pointer(b)
	b.custom_minimum_size = Vector2(0, 15)
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.pressed.connect(act)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var g: Control = KeyGlyphS.new()
	g.set("glyph", glyph)
	g.set("colour", colour)
	row.add_child(g)
	var l := UITheme.body(label, label_c, UITheme.FS_SMALL)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	row.add_child(l)
	if right != "":
		row.add_child(UITheme.body(right, right_c, UITheme.FS_SMALL))
	_box.add_child(b)


## A button at the foot, the chart's JUMP size.
func _act(text: String, on: Callable, click := true) -> Button:
	var b := Widgets.button(text, on, click)
	b.custom_minimum_size = Vector2(0, 24)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_foot.add_child(b)
	return b


# ---------------------------------------------------------------- SECTOR
func show_system() -> void:
	_clear()
	var v = screen.view
	var n: MapGen.MapNode = v.node
	var L: SystemLayout = v.layout
	_eyebrow("SECTOR")
	_name(v.star_name())
	_class(v.star_class())
	_blurb(MapGen.place_line(n))
	_rule()
	_row("BODIES", str(L.bodies.size()))
	if n.in_nebula:
		_row("NEBULA", "GLOWING" if n.nebula_emission else "COLD GAS")
	_gap()
	var beacons := _all_beacons()
	var open := 0
	for pair in beacons:
		if screen.overlay.spent_word(pair[1]).is_empty():
			open += 1
	if beacons.is_empty():
		_eyebrow("NOTHING OUT HERE WANTS YOU")
	else:
		_eyebrow("BEACONS - %d OPEN" % open if open > 0 else "BEACONS - ALL ANSWERED")
	for pair in beacons:
		_beacon_row(pair[0], pair[1])
	# A HULL ON OFFER, the one thing the sector's salvage rail still holds
	# (`SectorScreen._refresh_salvage`): the same row, the same DECIDE LATER.
	if Run.found_hull != null and not Run.salvage_hushed(screen.bag_here()):
		_gap()
		_eyebrow("A HULL, IF YOU WANT IT", UITheme.EMBER)
		_box.add_child(Widgets.hull_row(Run.found_hull, "TRANSFER", 0, func(what: String, h: Variant) -> void: screen.on_hull(what, h)))
		var later := Widgets.button("DECIDE LATER", func() -> void: screen.hush_hull())
		later.tooltip_text = Widgets.tip("Closes this. The hull stays on offer for the rest of the run.")
		_box.add_child(later)
	_gap()
	_blurb("Click a world or the star to learn about it.")
	var loot := _act("SECTOR LOOT", func() -> void: screen.open_sector_loot())
	loot.size_flags_horizontal = Control.SIZE_FILL
	_act("PLOT NEXT JUMP", func() -> void: screen.plot_next_jump(), false)


## Every beacon in the sector, as [body, beacon]; the pulsar's own on the star.
func _all_beacons() -> Array:
	var L: SystemLayout = screen.view.layout
	var out: Array = []
	for bi in L.bodies.size():
		for bc in L.bodies[bi].beacons:
			out.append([bi, bc])
	if screen.view.node.type == MapGen.NodeType.PULSAR:
		out.append([-1, null])
	return out


## A beacon as a row in the list: its glyph in its tag's colour, its title, and
## the band it came to once answered.
func _beacon_row(body: int, bc) -> void:
	var look: Array = screen.overlay.beacon_look(bc) if bc != null else [&"harvest", UITheme.TRACTOR]
	var title := ""
	if bc == null:
		title = "HARVEST THE BEAM"
	elif bc.dock:
		title = "DOCK"
	elif bc.core:
		title = "THE CUSTODIAN"
	else:
		title = String(screen.overlay.option_of(bc).get("title", "")).to_upper()
	var sw: Array = screen.overlay.spent_word(bc)
	var spent := not sw.is_empty()
	# WHERE IT IS, on the right, until it is answered and says how it went
	# (Jon: "it's unclear how to ... know what beacons there are")
	var v = screen.view
	var where: String = v.star_name() if body < 0 else _short(v.layout.bodies[body].name)
	_list_row(look[0], DIM if spent else look[1], title, DIM if spent else UITheme.ICE,
		sw[0] if spent else where, sw[1] if spent else UITheme.COLD,
		func() -> void: screen.open_beacon(body, bc))


## A body's name without the system's: "IOTA HOLLOW-2 II" is "II" in a list of
## the system's own bodies.
func _short(name: String) -> String:
	var sys: String = screen.view.star_name()
	return name.substr(sys.length()).strip_edges() if name.begins_with(sys) and name.length() > sys.length() else name


# ---------------------------------------------------------------- BODY / STAR
func show_body(i: int) -> void:
	_clear()
	var v = screen.view
	var L: SystemLayout = v.layout
	var b: SystemLayout.Body = null if i < 0 else L.bodies[i]
	_back("STAR" if b == null else ("WORLD" if b.world != &"" else String(b.kind).to_upper()), true)
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
	_name(v.star_name() if b == null else b.name)
	_class(v.star_class() if b == null else v.body_kind(b))
	_rule()
	if b != null:
		for f in v.facts(b):
			_row(f[0], f[1])
	else:
		var sf: Dictionary = SystemViewS.STAR_FACTS[v.kind]
		_row("CLASS", sf.cls)
		_row("SURFACE", sf.temp)
		_row("MASS", sf.mass)
		_row("RADIUS", sf.radius)
		_gap()
		_eyebrow("SATELLITES - %d" % L.bodies.size())
		for bi in L.bodies.size():
			var bd: SystemLayout.Body = L.bodies[bi]
			var tag: StringName = &"dock" if bd.kind == &"station" else (&"world" if bd.world != &"" else bd.kind)
			_list_row(tag, UITheme.COLD, bd.name, UITheme.ICE, v.body_kind(bd), UITheme.COLD,
				func() -> void: screen.select_body(bi))
		# THE STAR HOLDS THE WHOLE SECTOR, so it lists every beacon in it (Jon:
		# "this panel should also have all the BEACONS HERE for the sector")
		var all := _all_beacons()
		if not all.is_empty():
			_gap()
			_eyebrow("BEACONS - %d" % all.size())
			for pair in all:
				_beacon_row(pair[0], pair[1])
	if b != null:
		if not b.beacons.is_empty():
			_gap()
			_eyebrow("BEACONS HERE - %d" % b.beacons.size())
			for bc in b.beacons:
				_beacon_row(i, bc)
		# AND EVERY OTHER ONE, with where it is, so nothing out here is a secret
		var rest: Array = _all_beacons().filter(func(pair: Array) -> bool: return pair[0] != i)
		if not rest.is_empty():
			_gap()
			_eyebrow("ELSEWHERE IN THE SECTOR - %d" % rest.size())
			for pair in rest:
				_beacon_row(pair[0], pair[1])
	# THE WAY THERE: your ship flies to it and parks, as it does for a beacon
	var here: bool = screen.overlay.ship_park == i and screen.overlay.ship_fly_t0 < 0.0
	var go := _act("YOU ARE HERE" if here else "FLY HERE", func() -> void: screen.fly_to_body(i))
	go.disabled = here


func _process(_d: float) -> void:
	if _portrait != null and is_instance_valid(_portrait):
		_portrait.call("step", screen.view.t, Vector3(-0.83, -0.31, 0.47))


# ---------------------------------------------------------------- BEACON
func show_beacon(body: int, bc) -> void:
	_clear()
	var v = screen.view
	var n: MapGen.MapNode = v.node
	if bc == null or bc.dock or bc.core:
		var words: Array
		if bc == null:
			words = [v.star_name(), "NEUTRON STAR", "The pulsar's beam sweeps the system once a second. Hold the ship in it and the hull drinks heat.", "HARVESTED" if n.cleared else "HARVEST"]
		elif bc.dock:
			words = [v.layout.bodies[body].name if body >= 0 else v.star_name(), "STATION", "A station rides this orbit. Its berths are open and its decks are lit.", "DOCK"]
		else:
			words = ["THE CUSTODIAN", "CONTACT", "Something holds station at the edge of the disc. It has been waiting a long time, and it has seen you.", "ENGAGE"]
		_back("BEACON")
		_name(words[0])
		_class(words[1])
		_blurb(words[2])
		var act := _act(words[3], func() -> void: screen.take_action(bc))
		act.disabled = bc == null and n.cleared
		return
	var i: int = bc.opt
	var o: Dictionary = screen.overlay.option_of(bc)
	_back(" · ".join((o.get("tags", []) as Array).map(func(x): return String(x).to_upper())))
	_name(String(o.get("title", "")).to_upper(), EncounterDrawer.tag_colour(o).lerp(UITheme.ICE, 0.5))
	if body >= 0:
		_class("%s  ·  %s" % [v.layout.bodies[body].name, v.body_kind(v.layout.bodies[body])])
	if String(o.get("group", "")) != "":
		_wrap("ONE OF A SET: TAKING IT CLOSES THE OTHERS", UITheme.WARN, UITheme.FS_SMALL)
	_blurb(String(o.get("body", "")))
	_rule()
	var sw: Array = screen.overlay.spent_word(bc)
	if not sw.is_empty():
		_eyebrow(sw[0], sw[1])
		return
	var choices: Array = o.get("choices", [])
	for j in choices.size():
		var c: Dictionary = choices[j]
		var card := EncounterDrawer.choice_card(n, i, j, c, o, func(ii: int, jj: int) -> void: screen.take_choice(ii, jj))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_box.add_child(card)


# ---------------------------------------------------------------- RESULT
func show_result(i: int, out: Dictionary) -> void:
	_clear()
	var v = screen.view
	var n: MapGen.MapNode = v.node
	var o := OptionTable.by_id(n.options[i])
	var word := SkillCheck.band_name(out.band) if out.checked else ("LEFT ALONE" if out.stay else "RESOLVED")
	var ink: Color = SkillCheck.band_colour(out.band) if out.checked else UITheme.CHILL
	_eyebrow(String(o.get("title", "")).to_upper())
	_name(word, ink)
	_class(String(out.odds))
	_blurb(String((out.res as Dictionary).get("text", "")))
	if not (out.bill as Array).is_empty():
		_rule()
		for r in out.bill:
			_row(String(r.name), String(r.text), r.tone as Color)
	if OptionTable.pays_item(out.res) and not Run.dead:
		var left := Run.jetsam_left(n, Run.sector_jetsam(n, false))
		var claim := _act("REWARD", func() -> void: screen.open_prize())
		claim.disabled = left <= 0
	_act("CONTINUE", func() -> void: screen.panel_back())
