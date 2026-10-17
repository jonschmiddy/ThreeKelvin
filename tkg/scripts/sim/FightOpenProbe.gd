
extends RefCounted

## WHERE EVERYTHING ON THE FIGHT'S SCREEN IS, ONE FRAME AT A TIME, for the
## opening of a fight (`FightOpenFilm`, `FightOpenTest`). Every element that
## changes place or appears as a fight starts, by role, so the LOCAL screen a
## fight is started from and the fight's own screen are compared as one
## picture: a role is looked up on whichever screen is current.
##
## Each sample is `{role: [x, y, w, h, alpha]}` in game px (the 960 x 540
## canvas), alpha the product of every modulate up the tree (0 when hidden).
## Bob-free: your ship is its canvas's box (`ShipView.hull_rect`) and each enemy
## its holder, the box its layout gives it; the enemy's own fly-in is
## `enemy<i>_fly`, its art's offset from that box, kept apart because it is a
## flight and not a jump.
##
## Also says, per frame, whether a card or END TURN / FLEE / HAIL / a pile would
## take a click (`clickable`).

## Every role a sample can hold, in the order a report lists them.
const ROLES := ["screen", "ship", "plate", "band_quiet", "quiet_panel", "band_hand",
	"hand_panel", "end_turn", "flee", "hail", "draw_pile", "discard_pile", "energy",
	"turn", "event_band", "area", "convoy", "subject", "name_card"]


static func alpha_of(c: CanvasItem, through_screen: bool = false) -> float:
	if c == null or not is_instance_valid(c) or not c.is_inside_tree() or not c.is_visible_in_tree():
		return 0.0
	var a := c.self_modulate.a
	var n: Node = c
	while n != null and n is CanvasItem and (through_screen or not n is SectorScreen):
		a *= (n as CanvasItem).modulate.a
		n = n.get_parent()
	return a


static func _box(r: Rect2, a: float) -> Array:
	return [snappedf(r.position.x, 0.01), snappedf(r.position.y, 0.01),
		snappedf(r.size.x, 0.01), snappedf(r.size.y, 0.01), snappedf(a, 0.001)]


## WHERE A SUBJECT'S PIECES ARE DRAWN, in game px: every placed piece's picture
## (its sprite's rect, or a few px round its holder for one the planet painter
## draws), merged. Empty if it has none to draw.
static func subject_ink(s: LocalSubject) -> Rect2:
	var r := Rect2()
	var first := true
	for rec: Dictionary in s._placed:
		var node := rec.get("node") as Node2D
		if node == null or not is_instance_valid(node) or not node.is_visible_in_tree():
			continue
		var spr := rec.get("sprite") as Sprite2D
		var b := Rect2(node.global_position - Vector2(2.0, 2.0), Vector2(4.0, 4.0))
		if spr != null and spr.texture != null and spr.is_visible_in_tree():
			b = spr.get_global_transform() * spr.get_rect()
		r = b if first else r.merge(b)
		first = false
	return r


## The part of `c` its clipping holder lets through.
static func _clipped(c: Control, clip: Control) -> Rect2:
	var r := c.get_global_rect()
	if clip != null:
		r = r.intersection(clip.get_global_rect())
	return r


static func sample(sc: SectorScreen) -> Dictionary:
	var d := {}
	if sc == null or not is_instance_valid(sc) or sc._view == null:
		return d
	d.screen = _box(sc.get_global_rect(), alpha_of(sc, true))
	var sv: ShipView = sc._view.ship_view()
	if sv != null:
		# the canvas's box: where the ship is, whatever its flame or bob draws
		var r := sv.get_global_transform() * sv.hull_rect()
		d.ship = _box(r, alpha_of(sv))
	if sc._self_plate != null:
		d.plate = _box(sc._self_plate.get_global_rect(), alpha_of(sc._self_plate))
	if sc._quiet_holder != null:
		d.band_quiet = _box(sc._quiet_holder.get_global_rect(), alpha_of(sc._quiet_holder))
		d.quiet_panel = _box(_clipped(sc._quiet_wrap, sc._quiet_holder), alpha_of(sc._quiet_wrap))
	if sc._hand_holder != null:
		d.band_hand = _box(sc._hand_holder.get_global_rect(), alpha_of(sc._hand_holder))
		d.hand_panel = _box(_clipped(sc._hand_wrap, sc._hand_holder), alpha_of(sc._hand_wrap))
		for pair in [["end_turn", sc._end_button], ["flee", sc._flee_button],
				["hail", sc._hail_button], ["draw_pile", sc._draw_pile],
				["discard_pile", sc._discard_pile], ["energy", sc._energy],
				["turn", sc._deck_label]]:
			var c: Control = pair[1]
			# where it is on the panel, which the band clips as it rises
			if c != null:
				d[pair[0]] = _box(c.get_global_rect(), alpha_of(c))
	if sc._events != null and is_instance_valid(sc._events):
		d.event_band = _box(sc._events.get_global_rect(), alpha_of(sc._events))
	var v := sc._view
	if v._area != null:
		# (a place that draws nothing is nothing on screen)
		d.area = _box(v._area.get_global_rect(),
			alpha_of(v._area) if v._area._place_name() != &"" else 0.0)
	if v._convoy_pad != null:
		d.convoy = _box(v._convoy_pad.get_global_rect(), alpha_of(v._convoy_pad))
	for n in v.get_children():
		if n is LocalSubject:
			d.subject = _box((n as Control).get_global_rect(), alpha_of(n as CanvasItem))
			# (and what it draws: its pieces where they stand this frame. The box is
			# the whole view and says nothing about whether a piece is on it)
			var ink := subject_ink(n as LocalSubject)
			if ink.has_area():
				d.subject_ink = _box(ink, alpha_of(n as CanvasItem))
	var ghost := v.get_node_or_null("AreaLeaving") as Control
	if ghost != null:
		d.area_ghost = _box(ghost.get_global_rect(), alpha_of(ghost))
	if sc._card != null and is_instance_valid(sc._card):
		d.name_card = _box(sc._card.get_global_rect(), alpha_of(sc._card))
	# the enemies: the box the row gives each, its fly-in, its readouts
	for i in v._made.size():
		var s := v._made[i] as EnemySlot
		if s == null or not is_instance_valid(s):
			continue
		var a := alpha_of(s)
		d["enemy%d" % i] = _box(s.holder_rect(), a)
		d["enemy%d_fly" % i] = snappedf(s.art.position.x - s._art_base.x, 0.01)
		d["enemy%d_readout" % i] = _box(s.readout_rect_global(), a)
		d["enemy%d_intent" % i] = _box(s.intent_rect_global(), a)
	# the cards in the hand
	if sc._hand != null:
		var k := 0
		for c in sc._hand.get_children():
			if c is CardView and not (c as CardView).is_queued_for_deletion():
				d["card%d" % k] = _box((c as Control).get_global_rect(), alpha_of(c as CanvasItem))
				k += 1
	d.clickable = clickable(sc)
	return d


## What on the band would take a click now: every card that would be grabbed,
## and every button or pile that would answer a press.
static func clickable(sc: SectorScreen) -> Array:
	var out := []
	if sc == null or sc._hand_holder == null or not sc._hand_holder.is_visible_in_tree():
		return out
	if sc._hand != null:
		var k := 0
		for c in sc._hand.get_children():
			if c is CardView and not (c as CardView).is_queued_for_deletion():
				var cv := c as CardView
				if cv.is_visible_in_tree() and cv.playable and cv.mouse_filter == Control.MOUSE_FILTER_STOP \
						and not _blocked(sc, cv):
					out.append("card%d" % k)
				k += 1
	for pair in [["end_turn", sc._end_button], ["flee", sc._flee_button], ["hail", sc._hail_button]]:
		var b: Button = pair[1]
		if b != null and b.is_visible_in_tree() and not b.disabled \
				and b.mouse_filter != Control.MOUSE_FILTER_IGNORE and not _blocked(sc, b):
			out.append(pair[0])
	for pair2 in [["draw_pile", sc._draw_pile], ["discard_pile", sc._discard_pile]]:
		var p: Control = pair2[1]
		if p != null and p.is_visible_in_tree() and p.mouse_filter != Control.MOUSE_FILTER_IGNORE \
				and not _blocked(sc, p):
			out.append(pair2[0])
	return out


## A control is out of reach while something over the band eats the mouse
## (`SectorScreen._band_shield`), or while its middle is outside the band.
static func _blocked(sc: SectorScreen, c: Control) -> bool:
	var at := c.get_global_rect().get_center()
	if not sc._hand_holder.get_global_rect().has_point(at):
		return true
	var shield: Control = sc.get("_band_shield")
	return shield != null and is_instance_valid(shield) and shield.is_visible_in_tree() \
		and shield.mouse_filter == Control.MOUSE_FILTER_STOP and shield.get_global_rect().has_point(at)
