class_name LocalTag
extends Control

## THE QUIET LINE AS A NAME TAG (Jon, Nov 15, with the choices on your ship): with no shelf, LOCAL's
## one-liner (the system's or station's line, the Hellbender, a pulsar) pins to the place as a tag,
## its doors as bracketed words; the end of the run is a card in the middle with SUMMARY.
## Why: docs/why/ShipChoices.md#quiet-tag

const W_MAX := 250.0
const PAD := 7.0
const LINE_H := 11.0

var screen: Control = null
var events: LocalEventDrawer = null
## The line, its doors, and whether it is the card in the middle.
var line := ""
var card := false
var _lines: PackedStringArray = []
var _words: Array[ShipChoices.Tag] = []
var _key := ""
var _pin := Rect2()
var _lay_key := ""
## The Custodian's body on screen while it waits to be stripped (`Router.final_loot`).
var _body := Rect2()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name = "LocalTag"


## In the ship layout, the tag instead of the quiet drawer (which is hidden); false in the band's.
static func instead(on: Control, n: MapGen.MapNode, holder: Control, ev: LocalEventDrawer) -> bool:
	if LocalEventDrawer.layout != &"ship":
		return false
	holder.visible = false
	var t: LocalTag = null
	for c in on.get_children():
		if c is LocalTag:
			t = c
	if t == null:
		t = LocalTag.new()
		t.screen = on
		on.add_child(t)
	t.events = ev
	t.fill(n)
	return true


## What the tag says here and the doors on it; rebuilt only when that changes.
func fill(n: MapGen.MapNode) -> void:
	var doors: Array = []
	card = false
	if Run.dead:
		line = "The ship is lost. The run is over."
		doors = [["SUMMARY", Router.show_game_over]]
		card = true
	elif Router.final_loot:
		# a bracket on its body, like any other choice, and the word under it
		line = " "
		doors = [["SALVAGE THE CUSTODIAN", Router.open_core_body]]
	elif n == null:
		line = ""
	elif n.type in [MapGen.NodeType.SYSTEM, MapGen.NodeType.STATION] \
			and not (Run.hellbender_alive() and Run.hellbender_at == n.index):
		line = SectorScreen.here_line(n)
		# (beside the station you can see, "A STATION HERE" says nothing the picture does not)
		line = line.trim_prefix("A STATION HERE").trim_prefix(" · ")
		if Router.join_state() != Router.JOIN_NONE:
			line = "%s IS FIGHTING HERE" % Router.join_fight_names()
			if Router.join_state() != Router.JOIN_SHUT:
				doors.append(["JOIN FIGHT", Router.join_fight])
		# (only for an event put off: never while one is about to open on its own)
		if LocalEventDrawer.can_reopen(n) and events != null and events.page == &"" \
				and events.deferred.is_empty() and LocalEventDrawer.pending.is_empty() \
				and (events.put_off or EncounterDrawer.option_state(n, LocalEventDrawer.bar_option(n)).kind == &"left"):
			doors.append(["OPEN IT", events.open.bind(LocalEventDrawer.bar_option(n))])
		var pile := Run.sector_loot(n)
		var loose := Run.jetsam_left(n, pile) if pile != null else 0
		if loose > 0:
			doors.append(["SECTOR LOOT · %d" % loose, screen.call.bind(&"_open_loose")])
		if line == "" and not doors.is_empty():
			line = " "
	else:
		var q := EncounterDrawer.quiet_lines(n)
		line = String(q[0])
		if String(q[1]) != EncounterDrawer.TO_SECTOR:
			doors.append([String(q[1]), screen.call.bind(&"_on_action")])
	# ONLY A TAG THAT CARRIES SOMETHING TO DO (Jon, Nov 15: "this text is unnecessary"): the quiet
	# flavour lines go; the docking hint stays until the first dock. Why: docs/why/ShipChoices.md#quiet-tag
	var hint := DockMouth.HINT_LINE.trim_prefix("A STATION HERE").trim_prefix(" · ")
	if not card and not Router.final_loot and doors.is_empty() and line != hint:
		line = ""
	var key := "%s|%s|%s" % [line, card, ",".join(doors.map(func(d: Array) -> String: return String(d[0])))]
	if key == _key:
		return
	_key = key
	for w in _words:
		w.queue_free()
	_words.clear()
	for d: Array in doors:
		var w := ShipChoices.Tag.new()
		w.loot = true
		w.verb = String(d[0])
		w.name = String(d[0]).replace(" ", "").replace("·", "")
		add_child(w)
		w.size = w.want()
		w.pressed.connect(d[1] as Callable)
		w.hovered.connect(func(on: bool) -> void:
			w.hot = on
			w.queue_redraw()
			queue_redraw())
		_words.append(w)
	_wrap()
	_lay_key = ""


func _wrap() -> void:
	var f := UITheme.pixel_font()
	_lines = []
	var cur := ""
	for word in line.split(" ", false):
		var t := word if cur == "" else cur + " " + word
		if cur != "" and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x > W_MAX - PAD * 2.0:
			_lines.append(cur)
			cur = word
		else:
			cur = t
	if cur != "":
		_lines.append(cur)
	var w := 0.0
	for l in _lines:
		w = maxf(w, f.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x)
	var row := -4.0
	for t in _words:
		row += t.size.x + 4.0
	w = maxf(w, row)
	size = Vector2(ceilf(w) + PAD * 2.0, PAD * 2.0 + _lines.size() * LINE_H + (18.0 if not _words.is_empty() else 0.0))
	var x := PAD
	for t in _words:
		t.position = Vector2(x, PAD + _lines.size() * LINE_H + 2.0)
		x += t.size.x + 4.0


func _process(_d: float) -> void:
	var hide := line == "" or (events != null and is_instance_valid(events) and events.page != &"") \
		or ShipChoices.covered(events) \
		or (screen != null and screen.has_method(&"fighting") and bool(screen.call(&"fighting")))
	visible = not hide
	if hide:
		return
	_body = _body_now()
	_pin = _body if _body.has_area() else _pin_now()
	var key := "%s|%s|%s" % [_pin, size, get_parent_area_size()]
	if key != _lay_key:
		_lay_key = key
		_place()
		queue_redraw()


func _inv() -> Transform2D:
	return (get_parent() as CanvasItem).get_global_transform().affine_inverse() if get_parent() is CanvasItem else Transform2D()


## The Custodian's wreck as drawn, while it waits to be stripped; else `Rect2()`.
func _body_now() -> Rect2:
	if not Router.final_loot:
		return Rect2()
	var view := screen.get("_view") as EncounterView if screen != null else null
	var h := Router.core_body_here()
	var slot := view.wreck_slot(h) if view != null and h != null else null
	if slot == null or not slot.is_visible_in_tree():
		return Rect2()
	slot.hush_salvage(true)
	return _inv() * slot.drawn_box()


## The place: the station (its mouth, or its picture), the world you orbit, the event's subject,
## the star; or nowhere. At a station's system away from it, nowhere (it is not drawn here).
func _pin_now() -> Rect2:
	var inv := _inv()
	var face: Variant = screen.get("_face") if screen != null else null
	if face is StationFace and is_instance_valid(face) and (face as StationFace).is_visible_in_tree():
		var sf := face as StationFace
		var m: Vector2 = sf.mouth_g()
		if m.is_finite():
			# the mouth, out to the plate's edge: the tag stands off the station's picture
			var mr := sf.get_global_transform() * sf.mouth()
			return inv * mr.expand(Vector2(sf.plate_g(Vector2.ZERO).x, m.y))
	var view := screen.get("_view") as EncounterView if screen != null else null
	if view == null:
		return Rect2()
	var area: Variant = view.get("_area")
	if area is AreaView and (area as AreaView).is_visible_in_tree() and (area as AreaView).place_name() == &"station":
		var tex := DB.place_sprite(&"station")
		var sz := tex.get_size() if tex != null else Vector2(124, 52)
		var c := UiRect.of(area as AreaView).get_center()
		return inv * Rect2(c - sz * 0.5, sz)
	var n := Run.node_at()
	if n != null and n.type == MapGen.NodeType.STATION:
		return Rect2()
	var s := LocalSubject.of(view)
	if s != null and s.is_visible_in_tree():
		var u := Rect2()
		# (the biggest piece is who talks: far ships and loose bits round them are not)
		for r in s.ink_rects():
			if r.get_area() > u.get_area():
				u = r
		if u.has_area():
			return inv * u
	if view.backdrop != null:
		var ni := view.backdrop.near_info()
		if not ni.is_empty():
			var rr := float(ni.r)
			return inv * Rect2(Vector2(ni.at) - Vector2(rr, rr), Vector2(rr, rr) * 2.0)
		if view.backdrop.star != null:
			var sr := view.backdrop.star_px()
			return inv * Rect2(view.backdrop.star_global() - Vector2(sr, sr), Vector2(sr, sr) * 2.0)
	return Rect2()


func _at_face() -> bool:
	var face: Variant = screen.get("_face") if screen != null else null
	return face is StationFace and is_instance_valid(face) and (face as StationFace).is_visible_in_tree()


func _place() -> void:
	var room := Rect2(Vector2(ShipChoices.EDGE, ShipChoices.TOP), get_parent_area_size() - Vector2(ShipChoices.EDGE * 2.0, ShipChoices.TOP + ShipChoices.EDGE))
	var p := Vector2(room.get_center().x - size.x * 0.5, room.position.y + 24.0)
	if card:
		p = room.get_center() - size * 0.5
	elif _body.has_area():
		p = Vector2(_body.get_center().x - size.x * 0.5, _body.end.y + 6.0)
	elif _pin.has_area() and _at_face():
		# beside the station's mouth, on the side toward you, off the station's own picture
		var left := _pin.get_center().x > room.get_center().x
		p = Vector2(_pin.position.x - 12.0 - size.x if left else _pin.end.x + 12.0, _pin.get_center().y - size.y * 0.5)
	elif _pin.has_area():
		p = Vector2(_pin.get_center().x - size.x * 0.5, _pin.position.y - 12.0 - size.y)
	position = ShipChoices.clamp_into(Rect2(p, size), room).position.round()


func _draw() -> void:
	if _body.has_area():
		# the Custodian's body bracketed as a choice is, bright while its word is pointed at
		var hot := not _words.is_empty() and _words[0].hot
		ShipChoices.draw_brackets(self, Rect2(_body.position - position, _body.size).grow(2.0),
			Color(UITheme.MARK, ShipChoices.HOT_A if hot else ShipChoices.DIM_A))
		return
	# NO FRAME: the tag is not a thing you press (only its bracketed words are), so it is a dim
	# backing, as a choice's label is at rest
	draw_rect(Rect2(Vector2.ZERO, size), Color(ShipChoices.FILL, 0.75))
	var f := UITheme.pixel_font()
	var asc := f.get_ascent(UITheme.FS_SMALL)
	for i in _lines.size():
		draw_string(f, Vector2(PAD, PAD + i * LINE_H + asc), _lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, UITheme.CHILL)
	# the tick down to the place, when there is air between
	if not card and _pin.has_area() and not _body.has_area():
		var y := clampf(_pin.get_center().y - position.y, 4.0, size.y - 4.0)
		if _pin.position.x - position.x - 3.0 > size.x:
			draw_rect(Rect2(size.x, y, _pin.position.x - position.x - 3.0 - size.x, 1), Color(UITheme.MARK, 0.7))
			return
		if _pin.end.x - position.x + 3.0 < 0.0:
			draw_rect(Rect2(_pin.end.x - position.x + 3.0, y, -(_pin.end.x - position.x + 3.0), 1), Color(UITheme.MARK, 0.7))
			return
		var top := _pin.position.y - position.y - 3.0
		if top > size.y:
			var x := clampf(_pin.get_center().x - position.x, 6.0, size.x - 6.0)
			draw_rect(Rect2(x, size.y, 1, top - size.y), Color(UITheme.MARK, 0.7))
