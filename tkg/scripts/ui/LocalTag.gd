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
		line = "The Custodian is dead. Its body is yours to strip."
		doors = [["SALVAGE THE CUSTODIAN", Router.open_core_body]]
	elif n == null:
		line = ""
	elif n.type in [MapGen.NodeType.SYSTEM, MapGen.NodeType.STATION] \
			and not (Run.hellbender_alive() and Run.hellbender_at == n.index):
		line = SectorScreen.here_line(n)
		if Router.join_state() != Router.JOIN_NONE:
			line = "%s IS FIGHTING HERE" % Router.join_fight_names()
			if Router.join_state() != Router.JOIN_SHUT:
				doors.append(["JOIN FIGHT", Router.join_fight])
		if LocalEventDrawer.can_reopen(n) and events != null and events.page == &"":
			doors.append(["OPEN IT", events.open.bind(LocalEventDrawer.bar_option(n))])
		var pile := Run.sector_loot(n)
		var loose := Run.jetsam_left(n, pile) if pile != null else 0
		if loose > 0:
			doors.append(["SECTOR LOOT · %d" % loose, screen.call.bind(&"_open_loose")])
	else:
		var q := EncounterDrawer.quiet_lines(n)
		line = String(q[0])
		if String(q[1]) != EncounterDrawer.TO_SECTOR:
			doors.append([String(q[1]), screen.call.bind(&"_on_action")])
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
			w.queue_redraw())
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
		or (screen != null and screen.has_method(&"fighting") and bool(screen.call(&"fighting")))
	visible = not hide
	if hide:
		return
	_pin = _pin_now()
	var key := "%s|%s|%s" % [_pin, size, get_parent_area_size()]
	if key != _lay_key:
		_lay_key = key
		_place()
		queue_redraw()


## The place: the station's mouth, the world you orbit, the event's subject, the star; or nowhere.
func _pin_now() -> Rect2:
	var inv: Transform2D = (get_parent() as CanvasItem).get_global_transform().affine_inverse() if get_parent() is CanvasItem else Transform2D()
	var face: Variant = screen.get("_face") if screen != null else null
	if face is StationFace and is_instance_valid(face) and (face as StationFace).is_visible_in_tree():
		var m: Vector2 = (face as StationFace).mouth_g()
		if m.is_finite():
			return inv * Rect2(m - Vector2(16, 16), Vector2(32, 32))
	var view := screen.get("_view") as EncounterView if screen != null else null
	if view == null:
		return Rect2()
	var s := LocalSubject.of(view)
	if s != null and s.is_visible_in_tree():
		var u := Rect2()
		# (the biggest piece is who talks: far ships and loose bits round them are not)
		for r in s.drawn_rects():
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


func _place() -> void:
	var room := Rect2(Vector2(ShipChoices.EDGE, ShipChoices.TOP), get_parent_area_size() - Vector2(ShipChoices.EDGE * 2.0, ShipChoices.TOP + ShipChoices.EDGE))
	var p := room.get_center() - size * 0.5
	if not card and _pin.has_area():
		p = Vector2(_pin.get_center().x - size.x * 0.5, _pin.position.y - 12.0 - size.y)
	position = ShipChoices.clamp_into(Rect2(p, size), room).position.round()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(ShipChoices.FILL, 0.88))
	var e := Color(UITheme.MARK, 0.8)
	draw_rect(Rect2(0, 0, size.x, 1), e)
	draw_rect(Rect2(0, size.y - 1, size.x, 1), e)
	draw_rect(Rect2(0, 0, 1, size.y), e)
	draw_rect(Rect2(size.x - 1, 0, 1, size.y), e)
	var f := UITheme.pixel_font()
	var asc := f.get_ascent(UITheme.FS_SMALL)
	for i in _lines.size():
		draw_string(f, Vector2(PAD, PAD + i * LINE_H + asc), _lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, UITheme.CHILL)
	# the tick down to the place, when there is air between
	if not card and _pin.has_area():
		var top := _pin.position.y - position.y - 3.0
		if top > size.y:
			var x := clampf(_pin.get_center().x - position.x, 6.0, size.x - 6.0)
			draw_rect(Rect2(x, size.y, 1, top - size.y), Color(UITheme.MARK, 0.7))
