class_name ShipChoices
extends Control

## THE CHOICES ON YOUR OWN SHIP (Jon, Nov 15, C with BEAT): LOCAL's event with no band. The event tag pins
## to whoever talks; a second after its text is in, the choices settle onto the parts of your ship
## that would do the work (`ShipParts`); then the answer replaces the event tag, what you got rises over
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
## The event tag's tick to whoever talks, at its shortest.
const TICK := 10.0
## How far whoever talks may drift before the event tag and labels are laid again.
const PIN_SLACK := 24.0
const ROW_H := 11.0
const FILL := Color(0.039, 0.063, 0.094)
const WHITE := Color(1, 1, 1)

var drawer: LocalEventDrawer = null
var event_tag: EventTag = null
## &"event" or &"result".
var mode: StringName = &""
## The choices are on the ship (after the beat).
var showing := false
## This page's text was printed before: shown whole, and the choices with no beat.
var whole := false
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
## Where the event tag stands for this event, kept from step 1 to step 3: its side of whoever talks,
## its width, its tick and its slide along that side.
var _spot: Dictionary = {}
var _age := 0.0
## How long after an event opens its event tag may still be placed again.
const SPOT_SETTLE_S := 0.25
## The pieces of the scene round whoever talks (other ships, loose bits): the event tag keeps off them.
var _others: Array[Rect2] = []


## One choice on the ship: the part, its box, its label, the box you can click, and what it does.
class Mark:
	var part: StringName = &""
	## Where its label stands: up, down, left or right of the hull.
	var side: StringName = &""
	var rect := Rect2()
	var tag: Tag = null
	var hit: Tag = null
	var act := Callable()
	## What taking it would close, said on its label while you point at it.
	var warn := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# --------------------------------------------------------------- the pages

## Step 1: the event tag on whoever talks, nothing on your ship yet. Returns the event tag's text, to play.
func event(title: String, tag: String, tag_ink: Color, words: String) -> SignalText:
	_clear(&"event")
	_spot = {}
	_age = 0.0
	_event_tag(title, tag, tag_ink, words, UITheme.CHILL)
	var n := drawer.node
	var o := OptionTable.by_id(n.options[drawer.opt])
	var choices: Array = o.get("choices", [])
	# A WALK-AWAY OF ITS OWN TAKES THE BOW, and NOT NOW goes (Jon, Nov 15, A): to put it off you fly
	# off, and the place's tag keeps OPEN IT. Why: docs/why/ShipParts.md#parts
	var walk := ShipParts.walks_away(choices)
	var parts := ShipParts.assign(choices, not walk)
	for j in choices.size():
		var c: Dictionary = choices[j]
		var said := EncounterDrawer.choice_note(n, c)
		var words_j := OptionTable.label_of(c, n).to_upper()
		var m := _mark(parts[j], "%s: %s" % [ShipParts.word_of(parts[j]), words_j],
			String(said[&"note"]).to_upper(), said[&"tone"], "Choice%d" % j, drawer.choose.bind(j))
		m.tag.live = bool(said[&"open"])
		m.hit.live = bool(said[&"open"])
		m.warn = drawer.closes_line(c)
	if not walk:
		_mark(ShipParts.LEAVE, "%s: NOT NOW" % ShipParts.word_of(ShipParts.LEAVE), "", UITheme.COLD, "NotNow", drawer.not_now)
	showing = false
	_in = 0.0
	_show_marks(false)
	return event_tag.body


## The text is all here: the choices come onto the ship a beat later (at once with no motion).
func text_done() -> void:
	if mode != &"event" or showing:
		return
	if Router.animating() and is_inside_tree() and not whole:
		_wait = BEAT_S
	else:
		_arrive(false)


## Step 3: their answer in the event tag, what you got over your ship, the bow flying on.
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
	# (the same event tag, where it stood, with their answer in it: who spoke has not changed)
	_event_tag(String(o.get("title", "")).to_upper(), "", UITheme.COLD, String(res.get("text", "")), UITheme.CHILL)
	if out.get("checked", false):
		_rows.append(["%s · %s" % [String(out.get("odds", "")), word], ink])
	elif word != "RESOLVED":
		_rows.append([word, ink])
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
	if fight:
		var m := _mark(ShipParts.LEAVE, "%s: THEY ARE FIRING" % ShipParts.word_of(ShipParts.LEAVE), "", UITheme.LEAVE, "TheyAreFiring", drawer.fight_on)
		m.tag.ink = UITheme.LEAVE
	else:
		_bridge()
	_arrive(false)
	return event_tag.body


## "+1 ITEM", "+2 ITEMS": how many things landed on the pile (Jon, Nov 15: a count, not pictures).
static func _loot_word(out: Dictionary) -> String:
	var k := maxi(int(out.get("loot", 0)), 1)
	return "+%d ITEM%s" % [k, "" if k == 1 else "S"]


func clear() -> void:
	_clear(&"")


## AT REST, THE ONE WAY ON (Jon, Nov 15): nothing up on LOCAL, the bridge's SCAN SECTOR, dim
## until pointed at. Not in a fight, and not while an event is about to open (`_process`).
func idle() -> void:
	_clear(&"idle")
	event_tag = null
	_bridge()
	_arrive(false)


## BRIDGE: SCAN SECTOR, LOCAL zooming out to the sector map (as SECTOR does). Why: docs/why/ShipChoices.md#scan-sector
func _bridge() -> void:
	_mark(&"bridge", "%s: SCAN SECTOR" % ShipParts.word_of(&"bridge"), "", UITheme.COLD, "ScanSector", drawer.scan_sector)


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
	if event_tag != null:
		event_tag.queue_free()
		event_tag = null
	_key = ""
	queue_redraw()


func _event_tag(title: String, tag: String, tag_ink: Color, words: String, ink: Color) -> void:
	event_tag = EventTag.new()
	event_tag.name = "EventTag"
	add_child(event_tag)
	event_tag.setup(title, tag, tag_ink, words, ink)


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
		var t := _marks[i].tag
		t.hot = i == _hover and t.live
		t.note = _marks[i].warn if t.hot else ""
		var tall := t.size.y
		t.size = t.want()
		# (a label over the hull grows up, away from it, into the room kept for it in `_lay`)
		if _marks[i].side == &"up":
			t.position.y -= t.size.y - tall
		t.queue_redraw()
	queue_redraw()


# --------------------------------------------------------------- where things go

func _process(delta: float) -> void:
	# (stood down under the pile and the cutaway: nothing of ours drawn through either)
	var want := not covered(drawer) and not (mode == &"idle" and not drawer.idle_ok())
	if visible != want:
		visible = want
	if mode == &"" or not is_visible_in_tree():
		return
	if _wait >= 0.0:
		_wait -= delta
		if _wait < 0.0:
			_arrive(true)
	_age += delta
	if _age <= SPOT_SETTLE_S + delta and not _spot.is_empty():
		_key = ""
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
	var key := "%s|%s|%s|%s|%s" % [_hull, _pin, size, event_tag.size if event_tag != null else Vector2.ZERO, showing]
	if key != _key:
		_key = key
		_lay()
		queue_redraw()


## Your hull's drawn box here (its opaque pixels, the bob taken out), and which way it faces.
## Whether the loot screen or the cutaway is up over LOCAL: what is drawn on the scene stands down.
static func covered(d: LocalEventDrawer) -> bool:
	if d == null:
		return false
	if d.get("_transfer") != null:
		return true
	var cut: Variant = d.screen.get("_cutaway") if d.screen != null and is_instance_valid(d.screen) else null
	return cut is CutawayView and is_instance_valid(cut)


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
		_others.clear()
		for r in s.ink_rects():
			_others.append(inv * r)
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
				var r := m.tag.get_rect()
				# (the room its warning takes while pointed at)
				if m.warn != "" and m.tag.note == "":
					r = r.grow_individual(0.0, 11.0 if m.side == &"up" else 0.0, 0.0, 0.0 if m.side == &"up" else 11.0)
				taken.append(r)
	if event_tag != null:
		_lay_event_tag(room, taken)
		# (where the event tag found no clear place beside whoever talks, the labels give way to it)
		for m in _marks:
			if m.part != &"" and m.tag.get_rect().intersects(event_tag.get_rect()):
				_free(m, room)
	if _hull.has_area():
		_lay_stack(room, taken)


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
	for m in up + down:
		_free(m, room)


## A label still on whoever talks, the event tag or another label finds the nearest clear place in a lane
## over or under the hull (the nearest lanes first), searched out from its part.
func _free(m: Mark, room: Rect2) -> void:
	if _clear_at(m, m.tag.get_rect(), room):
		return
	var w := m.tag.size
	var cx := m.rect.get_center().x
	var other := &"down" if m.side == &"up" else &"up"
	var lanes: Array[Array] = []
	for k in 4:
		lanes.append([m.side, k])
		lanes.append([other, k])
	for lane: Array in lanes:
		var y := _hull.position.y - LEAD - w.y if lane[0] == &"up" else _hull.end.y + LEAD
		y += (-1.0 if lane[0] == &"up" else 1.0) * float(lane[1]) * (w.y + 4.0)
		for k in range(0, 60):
			for sgn: float in [1.0, -1.0]:
				var r := Rect2(Vector2(cx - w.x * 0.5 + sgn * k * 8.0, y), w)
				if _clear_at(m, r, room):
					m.tag.position = r.position.round()
					m.side = StringName(lane[0])
					return


func _clear_at(m: Mark, r: Rect2, room: Rect2) -> bool:
	if not room.encloses(r) or r.intersects(_hull) or (_pin.has_area() and r.intersects(_pin)):
		return false
	if event_tag != null and event_tag.is_inside_tree() and r.intersects(event_tag.get_rect()):
		return false
	for o in _marks:
		if o != m and o.part != &"" and o.tag.get_rect().intersects(r):
			return false
	return true


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
	if event_tag != null:
		cx = _off_event_tag(loot, cx, y, room)
	# (over the labels standing over the hull, the bridge's among them: nothing under another)
	var wide := 0.0
	for m in loot:
		wide = maxf(wide, m.tag.size.x)
	var f0 := UITheme.pixel_font()
	for row: Array in _rows:
		wide = maxf(wide, f0.get_string_size(String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x)
	for m in _marks:
		var r := m.tag.get_rect()
		if m.part != &"" and m.side == &"up" and r.end.x > cx - wide * 0.5 - GAP and r.position.x < cx + wide * 0.5 + GAP:
			y = minf(y, r.position.y - 4.0)
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


## THE EVENT TAG RIGHT BESIDE WHOEVER TALKS (Jon, Nov 15): over them, else under, else beside, a short
## tick between; wider (to `EventTag.W_MAX`) before it goes further off. Never on a ship, a label or the
## HUD, and never in a corner. Kept where it stood from step 1 to step 3 (`_spot`).
func _lay_event_tag(room: Rect2, taken: Array[Rect2]) -> void:
	# (labels can give way to the event tag, `_free`; the ships, the HUD and the goal line cannot)
	var soft := taken.duplicate()
	var keep: Array[Rect2] = [_hull]
	if Router.hud != null and Router.hud.goal != null and Router.hud.goal.is_visible_in_tree():
		keep.append(get_global_transform().affine_inverse() * UiRect.of(Router.hud.goal))
	keep.append_array(_others)
	var at := _pin
	if not at.has_area():
		# no one talks: over your ship and what is on it
		at = _hull
		for t in taken:
			at = at.merge(t)
	keep.append(at)
	# (chosen again while the scene settles round the opening -- the subject is built a frame or two
	# in -- and again if your ship's place moved or the kept place is no longer clear)
	var moved := not _spot.is_empty() and (_spot.hull as Rect2).position.distance_to(_hull.position) > PIN_SLACK
	if not _spot.is_empty() and _age > SPOT_SETTLE_S and not moved:
		event_tag.set_w(float(_spot.w))
		var kept := _kept_rect(at, event_tag.size, room)
		if mode == &"result" or _cover(kept, keep) + _cover(kept, soft) <= 0.0:
			event_tag.position = kept.position.round()
			return
	var best := {}
	var least := INF
	var best_r := Rect2()
	for gap: float in [TICK, TICK + 30.0, TICK + 70.0]:
		for w: float in [EventTag.W, EventTag.W + 20.0, EventTag.W_MAX]:
			event_tag.set_w(w)
			# UNDER whoever it is about, else beside, never over (Jon, Nov 15)
			for side: StringName in [&"down", &"right", &"left"]:
				# (slid along the side, but never past the one it is pinned to)
				for off: float in [0.0, 60.0, -60.0, 120.0, -120.0, 180.0, -180.0, 240.0, -240.0]:
					var r := clamp_into(_spot_rect(at, side, gap, off, event_tag.size), room)
					var cover := _cover(r, keep) * 100.0 + _cover(r, soft) + (0.0 if _faces(r, at, side) else 1e6)
					if cover < least:
						least = cover
						best = {side = side, w = w}
						best_r = r
					if cover <= 0.0:
						break
				if least <= 0.0:
					break
			if least <= 0.0:
				break
		if least <= 0.0:
			break
	event_tag.set_w(float(best.w))
	best_r.size = event_tag.size
	best.hull = _hull
	# (where it stands against whoever talks, so step 3's taller or shorter event tag stands there too:
	# over them it keeps its foot, under or beside them its head)
	best.dx = best_r.position.x - at.position.x
	match StringName(best.side):
		&"up":
			best.dy = at.position.y - best_r.end.y
		&"down":
			best.dy = best_r.position.y - at.end.y
		_:
			best.dy = best_r.position.y - at.position.y
	_spot = best
	event_tag.position = best_r.position.round()


## The kept place, for a event tag of size `hs` now.
func _kept_rect(at: Rect2, hs: Vector2, room: Rect2) -> Rect2:
	var p := Vector2(at.position.x + float(_spot.dx), 0.0)
	match StringName(_spot.side):
		&"up":
			p.y = at.position.y - float(_spot.dy) - hs.y
		&"down":
			p.y = at.end.y + float(_spot.dy)
		_:
			p.y = at.position.y + float(_spot.dy)
	return clamp_into(Rect2(p, hs), room)


## Whether a event tag at `r` still faces `at` across its side (so its tick is short and straight).
static func _faces(r: Rect2, at: Rect2, side: StringName) -> bool:
	if side == &"up":
		return r.end.y <= at.position.y and r.end.x - 12.0 > at.position.x and r.position.x + 12.0 < at.end.x
	if side == &"down":
		return r.position.y >= at.end.y and r.end.x - 12.0 > at.position.x and r.position.x + 12.0 < at.end.x
	if side == &"right":
		return r.position.x >= at.end.x and r.end.y - 12.0 > at.position.y and r.position.y + 12.0 < at.end.y
	return r.end.x <= at.position.x and r.end.y - 12.0 > at.position.y and r.position.y + 12.0 < at.end.y


## The event tag's box on `side` of `at`, `gap` off it, slid `off` along the side.
static func _spot_rect(at: Rect2, side: StringName, gap: float, off: float, hs: Vector2) -> Rect2:
	var c := at.get_center()
	var p: Vector2
	match side:
		&"up":
			p = Vector2(c.x - hs.x * 0.5 + off, at.position.y - gap - hs.y)
		&"down":
			p = Vector2(c.x - hs.x * 0.5 + off, at.end.y + gap)
		&"right":
			p = Vector2(at.end.x + gap, c.y - hs.y * 0.5 + off)
		_:
			p = Vector2(at.position.x - gap - hs.x, c.y - hs.y * 0.5 + off)
	return Rect2(p, hs)


## The reward stack's middle, slid along its row off the event tag when the event tag stood there first.
func _off_event_tag(loot: Array[Mark], cx: float, y: float, room: Rect2) -> float:
	var wide := 0.0
	var top := y
	for m in loot:
		wide = maxf(wide, m.tag.size.x)
		top -= m.tag.size.y + 2.0
	var f := UITheme.pixel_font()
	for row: Array in _rows:
		wide = maxf(wide, f.get_string_size(String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x)
		top -= ROW_H
	var box := Rect2(cx - wide * 0.5, top, wide, y - top)
	var h := event_tag.get_rect().grow(GAP)
	if not box.intersects(h):
		return cx
	var dl := h.position.x - box.end.x
	var dr := h.end.x - box.position.x
	if absf(dl) < absf(dr) and box.position.x + dl >= room.position.x or box.end.x + dr > room.end.x:
		return cx + dl
	return cx + dr


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
	if event_tag != null and _pin.has_area():
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


## The event tag's tick down (or across) to whoever talks.
func _draw_tick() -> void:
	var h := event_tag.get_rect()
	var col := Color(UITheme.MARK, 0.7)
	var x := clampf(_pin.get_center().x, maxf(h.position.x, _pin.position.x) + 6.0, minf(h.end.x, _pin.end.x) - 6.0)
	if _pin.position.y - 3.0 > h.end.y:
		draw_rect(Rect2(x, h.end.y, 1, _pin.position.y - 3.0 - h.end.y), col)
		return
	if _pin.end.y + 3.0 < h.position.y:
		draw_rect(Rect2(x, _pin.end.y + 3.0, 1, h.position.y - _pin.end.y - 3.0), col)
		return
	var y := clampf(_pin.get_center().y, maxf(h.position.y, _pin.position.y) + 6.0, minf(h.end.y, _pin.end.y) - 6.0)
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
	## A third line while pointed at: what taking it would close (the band's warning).
	var note := ""
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
		if note != "":
			w = maxf(w, f.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, ShipChoices.FS).x)
		var extra := 11.0 if note != "" else 0.0
		if loot:
			return Vector2(ceilf(w) + 12.0, 16.0)
		return Vector2(ceilf(w) + 12.0, (27.0 if cost != "" else 16.0) + extra)

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
		if note != "":
			var ny := (27.0 if cost != "" else 16.0) + asc
			draw_string(f, Vector2(6, ny), note, HORIZONTAL_ALIGNMENT_LEFT, -1, ShipChoices.FS, UITheme.WARN)


## The event tag: the title (gold) and its tag word, who or where it is from, then the text as it arrives.
class EventTag extends Control:
	const W := 280.0
	const W_MAX := 320.0
	var title := ""
	var tag := ""
	var tag_ink := UITheme.COLD
	var body: SignalText = null
	var _below := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(t: String, tg: String, ti: Color, words: String, ink: Color) -> void:
		title = t
		tag = tg
		tag_ink = ti
		var f := UITheme.pixel_font()
		var w := W
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
		return 19.0 + (12.0 if _below else 0.0)

	## A wider box for a tall text: the words laid again at the new width, the height to match.
	func set_w(w: float) -> void:
		var f := UITheme.pixel_font()
		var head := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ShipChoices.FS).x
		if tag != "":
			head += 8.0 + f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, ShipChoices.FS).x
		_below = head + 18.0 > w
		body.position = Vector2(9, _head_h())
		body.size = Vector2(w - 18.0, maxf(body.size.y, 1.0))
		size = Vector2(w, _head_h() + body.custom_minimum_size.y + 4.0)
		body.size.y = body.custom_minimum_size.y
		queue_redraw()

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
		if tag != "":
			if _below:
				draw_string(f, Vector2(9, 19 + asc), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, ShipChoices.FS, tag_ink)
			else:
				var x := 17.0 + f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ShipChoices.FS).x
				draw_string(f, Vector2(x, 7 + asc), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, ShipChoices.FS, tag_ink)