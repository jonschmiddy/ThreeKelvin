class_name ShipChoices
extends Control

## THE CHOICES ON YOUR OWN SHIP (Jon, Nov 15, C with BEAT): LOCAL's event with no band. The hail pins
## to whoever talks; a second after its text is in, the choices settle onto the parts of your ship
## that would do the work (`ShipParts`); then the answer replaces the hail, what you got rises over
## your ship and the bow flies on. Behind `LocalEventDrawer.layout`. Why: docs/why/ShipChoices.md#on-your-ship

## After the text is in, before the choices come (BEAT, Jon); the brackets' settle.
const BEAT_S := 1.0
const SETTLE_S := 0.22
const SETTLE_PX := 2.0
## The bracket under the mouse, and the rest.
const HOT_A := 0.95
const DIM_A := 0.5
const FS := UITheme.FS_SMALL
## The goal line's row under the HUD, and the screen's edge, kept clear.
const TOP := 18.0
const EDGE := 8.0
## A label's stand-off from the hull; labels in a row, apart.
const LEAD := 14.0
const GAP := 6.0
## How far whoever talks may drift before the hail and labels are laid again.
const PIN_SLACK := 24.0
const ROW_H := 11.0
const FILL := Color(0.039, 0.063, 0.094)
const WHITE := Color(1, 1, 1)

var drawer: LocalEventDrawer = null
var hail: Hail = null
## &"event" or &"result".
var mode: StringName = &""
## The choices are on the ship (after the beat).
var showing := false
var _wait := -1.0
var _in := 1.0
var _hover := -1
var _marks: Array[Mark] = []
## The reward stack's plain lines (nothing to press): [text, ink, position].
var _rows: Array = []
var _hull := Rect2()
var _bow_left := false
var _pin := Rect2()
var _key := ""


## One choice on the ship: the part, its box, its label, the box you can click, and what it does.
class Mark:
	var part: StringName = &""
	## Where its label stands: up, down, left or right of the hull.
	var side: StringName = &""
	var rect := Rect2()
	var tag: Tag = null
	var hit: Tag = null
	var act := Callable()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# --------------------------------------------------------------- the pages

## Step 1: the hail on whoever talks, nothing on your ship yet. Returns the hail's text, to play.
func event(title: String, tag: String, tag_ink: Color, src: String, words: String) -> SignalText:
	_clear(&"event")
	_hail(title, tag, tag_ink, src, UITheme.MARK, words, UITheme.CHILL)
	var n := drawer.node
	var o := OptionTable.by_id(n.options[drawer.opt])
	var choices: Array = o.get("choices", [])
	var parts := ShipParts.assign(choices)
	for j in choices.size():
		var c: Dictionary = choices[j]
		var said := EncounterDrawer.choice_note(n, c)
		var words_j := OptionTable.label_of(c, n).to_upper()
		var m := _mark(parts[j], "%s: %s" % [ShipParts.word_of(parts[j]), words_j],
			String(said[&"note"]).to_upper(), said[&"tone"], "Choice%d" % j, drawer.choose.bind(j))
		m.tag.live = bool(said[&"open"])
		m.hit.live = bool(said[&"open"])
	_mark(ShipParts.LEAVE, "%s: NOT NOW" % ShipParts.word_of(ShipParts.LEAVE), "", UITheme.COLD, "NotNow", drawer.not_now)
	showing = false
	_in = 0.0
	_show_marks(false)
	return hail.body


## The text is all here: the choices come onto the ship a beat later (at once with no motion).
func text_done() -> void:
	if mode != &"event" or showing:
		return
	if Router.animating() and is_inside_tree():
		_wait = BEAT_S
	else:
		_arrive(false)


## Step 3: their answer in the hail, what you got over your ship, the bow flying on.
func result(out: Dictionary) -> SignalText:
	_clear(&"result")
	var o := OptionTable.by_id(drawer.node.options[drawer.opt])
	var res: Dictionary = out.get("res", {})
	var fight := bool(res.get("fight", false)) and not bool(out.get("stay", false))
	var word := "RESOLVED"
	var ink := UITheme.MARK
	if out.get("stay", false):
		word = "LEFT ALONE · STILL OPEN"
		ink = UITheme.COLD
	elif out.get("checked", false):
		word = SkillCheck.band_name(out.band)
		ink = SkillColours.band_colour(out.band)
	elif fight:
		word = "ENGAGED"
		ink = UITheme.LEAVE
	_hail(String(o.get("title", "")).to_upper(), "", UITheme.COLD, word, ink,
		String(res.get("text", "")), UITheme.CHILL if ink == UITheme.COLD or ink == UITheme.MARK else ink)
	if out.get("checked", false):
		_rows.append([String(out.get("odds", "")), ink])
	for b: Dictionary in out.get("bill", []):
		if int(b.n) != 0:
			_rows.append(["%+d %s" % [int(b.n), String(b.name)], UITheme.HOT if bool(b.good) else b.tone])
	if OptionResolve.shows_reward(out) and not Run.dead:
		if Run.jetsam_left(drawer.node, Run.sector_jetsam(drawer.node, false)) > 0:
			_loot(_loot_word(out), "Reward", drawer.open_reward)
		else:
			_rows.append(["TAKEN", UITheme.COLD])
	if out.get("stay", false):
		_loot("CHOOSE AGAIN", "ChooseAgain", drawer.open.bind(drawer.opt))
	var bow := "%s: " % ShipParts.word_of(ShipParts.LEAVE)
	if fight:
		var m := _mark(ShipParts.LEAVE, bow + "THEY ARE FIRING", "", UITheme.LEAVE, "TheyAreFiring", drawer.fight_on)
		m.tag.ink = UITheme.LEAVE
	else:
		_mark(ShipParts.LEAVE, bow + "FLY ON", "", UITheme.COLD, "Continue", drawer.continue_on)
	_arrive(false)
	return hail.body


## "+1 PART", "+2 PARTS", "+1 THING": what landed on the pile, by what it is.
static func _loot_word(out: Dictionary) -> String:
	var k := maxi(int(out.get("loot", 0)), 1)
	var parts := true
	for g: Dictionary in out.get("got", []):
		if bool(g.get("gain", false)) and StringName(g.get("kind", &"")) != &"part" and StringName(g.get("kind", &"")) != &"place":
			parts = false
	return "+%d %s%s" % [k, "PART" if parts else "THING", "" if k == 1 else "S"]


func clear() -> void:
	_clear(&"")


func _clear(m: StringName) -> void:
	mode = m
	showing = false
	_wait = -1.0
	_hover = -1
	for mk in _marks:
		if mk.tag != null:
			mk.tag.queue_free()
		if mk.hit != null:
			mk.hit.queue_free()
	_marks.clear()
	_rows.clear()
	if hail != null:
		hail.queue_free()
		hail = null
	_key = ""
	queue_redraw()


func _hail(title: String, tag: String, tag_ink: Color, src: String, src_ink: Color, words: String, ink: Color) -> void:
	hail = Hail.new()
	hail.name = "Hail"
	add_child(hail)
	hail.setup(title, tag, tag_ink, src, src_ink, words, ink)


## A choice's label and its click box on part `p` (or, with `p` empty, a word in the reward stack).
func _mark(p: StringName, verb: String, cost: String, cost_ink: Color, nm: String, act: Callable) -> Mark:
	var m := Mark.new()
	m.part = p
	m.act = act
	var k := _marks.size()
	m.tag = Tag.new()
	m.tag.name = nm
	m.tag.verb = verb
	m.tag.cost = cost
	m.tag.cost_ink = cost_ink
	add_child(m.tag)
	m.tag.size = m.tag.want()
	m.tag.pressed.connect(_press.bind(k))
	m.tag.hovered.connect(_hovered.bind(k))
	if p != &"":
		m.hit = Tag.new()
		m.hit.bare = true
		m.hit.name = nm + "Part"
		add_child(m.hit)
		m.hit.pressed.connect(_press.bind(k))
		m.hit.hovered.connect(_hovered.bind(k))
	_marks.append(m)
	return m


func _loot(word: String, nm: String, act: Callable) -> void:
	var m := _mark(&"", word, "", UITheme.COLD, nm, act)
	m.tag.loot = true
	m.tag.size = m.tag.want()


func _arrive(settle: bool) -> void:
	_wait = -1.0
	showing = true
	_in = 0.0 if settle else 1.0
	_show_marks(true)
	_key = ""


func _show_marks(on: bool) -> void:
	for m in _marks:
		m.tag.visible = on
		m.tag.modulate.a = _in
		if m.hit != null:
			m.hit.visible = on


func _press(k: int) -> void:
	if not showing or k < 0 or k >= _marks.size():
		return
	var m := _marks[k]
	if not m.tag.live:
		return
	m.act.call()


func _hovered(on: bool, k: int) -> void:
	var was := _hover
	if on:
		_hover = k
	elif _hover == k:
		_hover = -1
	if was == _hover:
		return
	for i in _marks.size():
		_marks[i].tag.hot = i == _hover and _marks[i].tag.live
		_marks[i].tag.queue_redraw()
	queue_redraw()


# --------------------------------------------------------------- where things go

func _process(delta: float) -> void:
	if mode == &"" or not is_visible_in_tree():
		return
	if _wait >= 0.0:
		_wait -= delta
		if _wait < 0.0:
			_arrive(true)
	if showing and _in < 1.0:
		_in = minf(1.0, _in + delta / SETTLE_S)
		for m in _marks:
			m.tag.modulate.a = _in
		queue_redraw()
	_hull = _hull_now()
	# (a tumbling subject's box changes every frame: nothing that can be clicked follows it closely)
	var pin := _pin_now()
	if pin.has_area() != _pin.has_area() or pin.position.distance_to(_pin.position) > PIN_SLACK 			or pin.end.distance_to(_pin.end) > PIN_SLACK:
		_pin = pin
	var key := "%s|%s|%s|%s|%s" % [_hull, _pin, size, hail.size if hail != null else Vector2.ZERO, showing]
	if key != _key:
		_key = key
		_lay()
		queue_redraw()


## Your hull's drawn box here (its opaque pixels, the bob taken out), and which way it faces.
func _hull_now() -> Rect2:
	var view := _view()
	var sv := view.ship_view() if view != null else null
	if sv == null or not sv.is_visible_in_tree():
		return Rect2()
	var r := sv.ship_rect()
	var xf := get_global_transform().affine_inverse() * sv.get_global_transform()
	var a := xf * r.position
	var b := xf * r.end
	_bow_left = b.x < a.x
	return Rect2(a, b - a).abs()


func _view() -> EncounterView:
	if drawer == null or drawer.screen == null or not is_instance_valid(drawer.screen):
		return null
	return drawer.screen.get("_view") as EncounterView


## Whoever talks: the event's subject as drawn, else the world you orbit; `Rect2()` for no one.
func _pin_now() -> Rect2:
	var view := _view()
	if view == null:
		return Rect2()
	var inv := get_global_transform().affine_inverse()
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
			var at: Vector2 = ni.at
			var rr := float(ni.r)
			return inv * Rect2(at - Vector2(rr, rr), Vector2(rr, rr) * 2.0)
	return Rect2()


func _lay() -> void:
	var room := Rect2(Vector2(EDGE, TOP), size - Vector2(EDGE * 2.0, TOP + EDGE))
	var taken: Array[Rect2] = []
	if _hull.has_area():
		taken.append(_hull)
		_lay_tags(room)
		for m in _marks:
			if m.part != &"":
				taken.append(m.tag.get_rect())
		_lay_stack(room, taken)
	if hail != null:
		_lay_hail(room, taken)


## Each label off its part, on its side; a row that collides spreads, then splits in two lanes.
func _lay_tags(room: Rect2) -> void:
	var up: Array[Mark] = []
	var down: Array[Mark] = []
	for m in _marks:
		if m.part == &"":
			continue
		m.rect = ShipParts.rect_of(m.part, _hull, _bow_left)
		if m.hit != null:
			m.hit.position = m.rect.position
			m.hit.size = m.rect.size
		var w := m.tag.size
		var c := m.rect.get_center()
		m.side = ShipParts.side_of(m.part, _bow_left)
		if m.side == &"left" or m.side == &"right":
			var x := _hull.position.x - LEAD - w.x if m.side == &"left" else _hull.end.x + LEAD
			var r := Rect2(Vector2(x, c.y - w.y * 0.5), w)
			# (no room beside the hull, or whoever talks is there: it stands under it instead)
			if room.encloses(r) and not (_pin.has_area() and r.intersects(_pin)):
				m.tag.position = r.position.round()
				continue
			m.side = &"down"
		if m.side == &"up":
			m.tag.position = Vector2(c.x - w.x * 0.5, _hull.position.y - LEAD - w.y)
			up.append(m)
		else:
			m.tag.position = Vector2(c.x - w.x * 0.5, _hull.end.y + LEAD)
			down.append(m)
		m.tag.position = clamp_into(Rect2(m.tag.position, w), room).position.round()
	_spread(up, room, -1.0)
	_spread(down, room, 1.0)
	for row: Array[Mark] in [up, down]:
		_dodge_row(row, room)
		for m in row:
			_dodge(m, room)


## A row with a label on whoever talks slides whole along itself, off them, when the room allows.
func _dodge_row(row: Array[Mark], room: Rect2) -> void:
	if row.is_empty() or not _pin.has_area():
		return
	var lo := INF
	var hi := -INF
	var hit := false
	for m in row:
		var t := m.tag.get_rect()
		lo = minf(lo, t.position.x)
		hi = maxf(hi, t.end.x)
		hit = hit or t.intersects(_pin)
	if not hit:
		return
	var moves: Array[float] = [_pin.position.x - GAP - hi, _pin.end.x + GAP - lo]
	moves.sort_custom(func(a: float, b: float) -> bool: return absf(a) < absf(b))
	for dx in moves:
		if lo + dx >= room.position.x and hi + dx <= room.end.x:
			for m in row:
				m.tag.position.x = roundf(m.tag.position.x + dx)
			return


## A label on whoever talks slides off them along its row, if the row has room there.
func _dodge(m: Mark, room: Rect2) -> void:
	var t := m.tag.get_rect()
	if not _pin.has_area() or not t.intersects(_pin):
		return
	var moves: Array[float] = [_pin.position.x - GAP - t.end.x, _pin.end.x + GAP - t.position.x]
	moves.sort_custom(func(a: float, b: float) -> bool: return absf(a) < absf(b))
	for dx in moves:
		var r := Rect2(t.position + Vector2(dx, 0.0), t.size)
		if not room.encloses(r):
			continue
		var clear := true
		for o in _marks:
			if o != m and o.part != &"" and o.tag.get_rect().intersects(r):
				clear = false
		if clear:
			m.tag.position = r.position.round()
			return


func _spread(row: Array[Mark], room: Rect2, dir: float) -> void:
	if row.size() < 2:
		return
	row.sort_custom(func(a: Mark, b: Mark) -> bool: return a.tag.position.x < b.tag.position.x)
	var need := -GAP
	for m in row:
		need += m.tag.size.x + GAP
	if need > room.size.x:
		# two lanes: every other label one lane further off the hull
		for i in range(1, row.size(), 2):
			var t := row[i].tag
			t.position.y += dir * (t.size.y + 4.0)
		var odd: Array[Mark] = []
		var even: Array[Mark] = []
		for i in row.size():
			(odd if i % 2 == 1 else even).append(row[i])
		_spread(even, room, dir)
		_spread(odd, room, dir)
		return
	for i in range(1, row.size()):
		var prev := row[i - 1].tag
		var t := row[i].tag
		t.position.x = maxf(t.position.x, prev.position.x + prev.size.x + GAP)
	var over := row[row.size() - 1].tag.get_rect().end.x - room.end.x
	if over > 0.0:
		for m in row:
			m.tag.position.x -= over
		var under := room.position.x - row[0].tag.position.x
		if under > 0.0:
			for m in row:
				m.tag.position.x += under


## The reward stack, over your ship's middle, the nearest line lowest.
func _lay_stack(room: Rect2, taken: Array[Rect2]) -> void:
	var loot: Array[Mark] = []
	for m in _marks:
		if m.part == &"":
			loot.append(m)
	if loot.is_empty() and _rows.is_empty():
		return
	var cx := _hull.get_center().x
	var y := _hull.position.y - 10.0
	for i in range(loot.size() - 1, -1, -1):
		var t := loot[i].tag
		y -= t.size.y
		t.position = clamp_into(Rect2(Vector2(cx - t.size.x * 0.5, y), t.size), room).position.round()
		taken.append(t.get_rect())
		y -= 2.0
	var f := UITheme.pixel_font()
	for i in range(_rows.size() - 1, -1, -1):
		var w := f.get_string_size(String(_rows[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
		y -= ROW_H
		var r := clamp_into(Rect2(Vector2(cx - w * 0.5, y), Vector2(w, ROW_H)), room)
		if _rows[i].size() < 3:
			_rows[i].append(Vector2.ZERO)
		_rows[i][2] = r.position.round()
		taken.append(r)


## The hail over whoever talks, else under or beside them, else in a top corner: the place that
## covers least of them, your ship and everything on it.
func _lay_hail(room: Rect2, taken: Array[Rect2]) -> void:
	var hs := hail.size
	var tries: Array[Vector2] = []
	var keep := taken.duplicate()
	# (the goal line under the HUD)
	if Router.hud != null and Router.hud.goal != null and Router.hud.goal.is_visible_in_tree():
		keep.append(get_global_transform().affine_inverse() * UiRect.of(Router.hud.goal))
	if _pin.has_area():
		var pc := _pin.get_center()
		keep.append(_pin)
		tries.append(Vector2(pc.x - hs.x * 0.5, _pin.position.y - 12.0 - hs.y))
		tries.append(Vector2(pc.x - hs.x * 0.5, _pin.end.y + 12.0))
		tries.append(Vector2(_pin.end.x + 12.0, pc.y - hs.y * 0.5))
		tries.append(Vector2(_pin.position.x - 12.0 - hs.x, pc.y - hs.y * 0.5))
	tries.append(Vector2(room.end.x - hs.x, room.position.y))
	tries.append(room.position)
	tries.append(room.end - hs)
	tries.append(Vector2(room.position.x, room.end.y - hs.y))
	if _hull.has_area():
		tries.append(Vector2(_hull.get_center().x - hs.x * 0.5, _hull.end.y + LEAD + 40.0))
	var best := Rect2()
	var least := INF
	for p in tries:
		var r := clamp_into(Rect2(p, hs), room)
		var cover := _cover(r, keep)
		if cover < least:
			least = cover
			best = r
		if cover <= 0.0:
			break
	if least > 0.0:
		# nowhere it was asked to go is clear: the clear place nearest the first ask
		var want := best.position
		var near := INF
		for y in range(int(room.position.y), int(room.end.y - hs.y) + 1, 8):
			for x in range(int(room.position.x), int(room.end.x - hs.x) + 1, 8):
				var r := Rect2(Vector2(x, y), hs)
				var d := r.position.distance_squared_to(want)
				if d < near and _cover(r, keep) <= 0.0:
					near = d
					best = r
	hail.position = best.position.round()


static func _cover(r: Rect2, keep: Array) -> float:
	var cover := 0.0
	for t: Rect2 in keep:
		cover += r.grow(2.0).intersection(t).get_area()
	return cover


static func clamp_into(r: Rect2, room: Rect2) -> Rect2:
	var p := r.position
	p.x = clampf(p.x, room.position.x, maxf(room.position.x, room.end.x - r.size.x))
	p.y = clampf(p.y, room.position.y, maxf(room.position.y, room.end.y - r.size.y))
	return Rect2(p, r.size)


# --------------------------------------------------------------- drawing

func _draw() -> void:
	if hail != null and _pin.has_area():
		_draw_tick()
	var f := UITheme.pixel_font()
	var asc := f.get_ascent(FS)
	for row: Array in _rows:
		if row.size() >= 3:
			draw_string(f, Vector2(row[2]) + Vector2(0, asc), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, FS, row[1])
	if not showing:
		return
	for k in _marks.size():
		var m := _marks[k]
		if m.part == &"":
			continue
		var a := (HOT_A if k == _hover else DIM_A) * _in
		var r := m.rect.grow((1.0 - _in) * SETTLE_PX)
		draw_brackets(self, r, Color(UITheme.MARK, a))
		_draw_leader(m, Color(UITheme.MARK, (0.8 if k == _hover else 0.4) * _in))


## The hail's tick down (or across) to whoever talks.
func _draw_tick() -> void:
	var h := hail.get_rect()
	var col := Color(UITheme.MARK, 0.7)
	var x := clampf(_pin.get_center().x, h.position.x + 6.0, h.end.x - 6.0)
	if _pin.position.y - 3.0 > h.end.y:
		draw_rect(Rect2(x, h.end.y, 1, _pin.position.y - 3.0 - h.end.y), col)
		return
	if _pin.end.y + 3.0 < h.position.y:
		draw_rect(Rect2(x, _pin.end.y + 3.0, 1, h.position.y - _pin.end.y - 3.0), col)
		return
	var y := clampf(_pin.get_center().y, h.position.y + 6.0, h.end.y - 6.0)
	if _pin.position.x - 3.0 > h.end.x:
		draw_rect(Rect2(h.end.x, y, _pin.position.x - 3.0 - h.end.x, 1), col)
	elif _pin.end.x + 3.0 < h.position.x:
		draw_rect(Rect2(_pin.end.x + 3.0, y, h.position.x - _pin.end.x - 3.0, 1), col)


## From the part's edge to its label: straight out, then along to the label if it was pushed aside.
func _draw_leader(m: Mark, col: Color) -> void:
	var t := m.tag.get_rect()
	var c := m.rect.get_center().round()
	match m.side:
		&"up", &"down":
			var up := m.side == &"up"
			var y0 := m.rect.position.y - 2.0 if up else m.rect.end.y + 1.0
			var y1 := t.end.y if up else t.position.y
			var x1 := clampf(c.x, t.position.x + 3.0, t.end.x - 4.0)
			var mid := roundf((y0 + y1) * 0.5)
			_vline(c.x, y0, mid, col)
			_hline(mid, c.x, x1, col)
			_vline(x1, mid, y1, col)
		_:
			var right := t.position.x > m.rect.end.x
			var x0 := m.rect.end.x + 1.0 if right else m.rect.position.x - 2.0
			var x1b := t.position.x if right else t.end.x
			var y1b := clampf(c.y, t.position.y + 3.0, t.end.y - 4.0)
			var midx := roundf((x0 + x1b) * 0.5)
			_hline(c.y, x0, midx, col)
			_vline(midx, c.y, y1b, col)
			_hline(y1b, midx, x1b, col)


func _vline(x: float, a: float, b: float, col: Color) -> void:
	draw_rect(Rect2(x, minf(a, b), 1, absf(b - a) + 1.0), col)


func _hline(y: float, a: float, b: float, col: Color) -> void:
	draw_rect(Rect2(minf(a, b), y, absf(b - a) + 1.0, 1), col)


## Four L corners on a box, the maps' R1 mark (`MarkOutline.draw_bracket_mark`) stretched to a
## rectangle: each arm `MarkOutline.BRACKET_ARM` px on from its corner, 1 px, whole pixels.
static func draw_brackets(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var q := Rect2(r.position.round(), r.size.round())
	var k := float(MarkOutline.BRACKET_ARM + 1)
	for s: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var cx := q.position.x + s.x * (q.size.x - 1.0)
		var cy := q.position.y + s.y * (q.size.y - 1.0)
		ci.draw_rect(Rect2(cx - s.x * (k - 1.0), cy, k, 1), col)
		ci.draw_rect(Rect2(cx, cy - s.y * (k - 1.0), 1, k), col)


# --------------------------------------------------------------- the pieces

## A label on your ship, a word in the reward stack, or (bare) the click box on a part.
class Tag extends Control:
	signal pressed
	signal hovered(on: bool)
	var verb := ""
	var cost := ""
	var cost_ink := UITheme.COLD
	var ink := UITheme.ICE
	var hot := false
	## Pressable now (a price you cannot pay is not).
	var live := true
	## A word in the reward stack: no box, brackets round it.
	var loot := false
	## The click box on a part: draws nothing.
	var bare := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		mouse_entered.connect(func() -> void: hovered.emit(true))
		mouse_exited.connect(func() -> void: hovered.emit(false))

	func want() -> Vector2:
		var f := UITheme.pixel_font()
		var w := f.get_string_size(verb, HORIZONTAL_ALIGNMENT_LEFT, -1, ShipChoices.FS).x
		if cost != "":
			w = maxf(w, f.get_string_size(cost, HORIZONTAL_ALIGNMENT_LEFT, -1, ShipChoices.FS).x)
		if loot:
			return Vector2(ceilf(w) + 12.0, 16.0)
		return Vector2(ceilf(w) + 12.0, 27.0 if cost != "" else 16.0)

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			pressed.emit()

	func _draw() -> void:
		if bare:
			return
		var f := UITheme.pixel_font()
		var asc := f.get_ascent(ShipChoices.FS)
		var r := Rect2(Vector2.ZERO, size)
		if loot:
			ShipChoices.draw_brackets(self, r, Color(UITheme.MARK, ShipChoices.HOT_A if hot else ShipChoices.DIM_A))
			draw_string(f, Vector2(6, 4 + asc), verb, HORIZONTAL_ALIGNMENT_LEFT, -1, ShipChoices.FS, UITheme.HOT)
			return
		draw_rect(r, Color(ShipChoices.FILL, 0.92 if hot else 0.75))
		if hot:
			var e := Color(UITheme.MARK, 0.9)
			draw_rect(Rect2(0, 0, size.x, 1), e)
			draw_rect(Rect2(0, size.y - 1, size.x, 1), e)
			draw_rect(Rect2(0, 0, 1, size.y), e)
			draw_rect(Rect2(size.x - 1, 0, 1, size.y), e)
		var vi := ShipChoices.WHITE if hot else Color(ink, 0.8 if live else 0.5)
		draw_string(f, Vector2(6, 5 + asc), verb, HORIZONTAL_ALIGNMENT_LEFT, -1, ShipChoices.FS, vi)
		if cost != "":
			# the price and the odds stay legible on a dim label: danger is read at a glance
			draw_string(f, Vector2(6, 16 + asc), cost, HORIZONTAL_ALIGNMENT_LEFT, -1, ShipChoices.FS, Color(cost_ink, 1.0 if hot else 0.85))


## The hail: the title (gold) and its tag word, who or where it is from, then the text as it arrives.
class Hail extends Control:
	const W := 280.0
	const W_MAX := 360.0
	var title := ""
	var tag := ""
	var tag_ink := UITheme.COLD
	var src := ""
	var src_ink := UITheme.MARK
	var body: SignalText = null
	var _below := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(t: String, tg: String, ti: Color, s: String, si: Color, words: String, ink: Color) -> void:
		title = t
		tag = tg
		tag_ink = ti
		src = s
		src_ink = si
		var f := UITheme.pixel_font()
		var w := clampf(f.get_string_size(src, HORIZONTAL_ALIGNMENT_LEFT, -1, ShipChoices.FS).x + 18.0, W, W_MAX)
		var head := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ShipChoices.FS).x
		if tag != "":
			head += 8.0 + f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, ShipChoices.FS).x
		if head + 18.0 > w:
			w = clampf(head + 18.0, w, W_MAX)
		_below = head + 18.0 > w
		body = SignalText.new()
		body.name = "Text"
		body.by_word = true
		body.ink = ink
		body.text = words
		add_child(body)
		body.position = Vector2(9, _head_h())
		body.size = Vector2(w - 18.0, 10)
		size = Vector2(w, _head_h() + 14.0)

	func _head_h() -> float:
		return 31.0 + (12.0 if _below else 0.0)

	func _process(_d: float) -> void:
		if body == null:
			return
		var want := _head_h() + body.custom_minimum_size.y + 4.0
		if not is_equal_approx(size.y, want):
			size.y = want
			body.size.y = body.custom_minimum_size.y
			queue_redraw()

	func _draw() -> void:
		var f := UITheme.pixel_font()
		var asc := f.get_ascent(ShipChoices.FS)
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(ShipChoices.FILL, 0.88))
		var e := Color(UITheme.MARK, 0.8)
		draw_rect(Rect2(0, 0, size.x, 1), e)
		draw_rect(Rect2(0, size.y - 1, size.x, 1), e)
		draw_rect(Rect2(0, 0, 1, size.y), e)
		draw_rect(Rect2(size.x - 1, 0, 1, size.y), e)
		draw_string(f, Vector2(9, 7 + asc), title, HORIZONTAL_ALIGNMENT_LEFT, -1, ShipChoices.FS, UITheme.HOT)
		var y := 19.0
		if tag != "":
			if _below:
				draw_string(f, Vector2(9, y + asc), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, ShipChoices.FS, tag_ink)
				y += 12.0
			else:
				var x := 17.0 + f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ShipChoices.FS).x
				draw_string(f, Vector2(x, 7 + asc), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, ShipChoices.FS, tag_ink)
		draw_string(f, Vector2(9, y + asc), src, HORIZONTAL_ALIGNMENT_LEFT, -1, ShipChoices.FS, src_ink)
