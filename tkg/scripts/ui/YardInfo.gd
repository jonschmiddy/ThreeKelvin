class_name YardInfo
extends RefCounted

## What a picked ship comes with, on the front door (Jon's B2, Nov 12: "show the
## manufacturer information", "show the installed modules... they do come with a
## standard deck of cards"): the maker's block in the band, the fitted parts
## spelled out, the weapons on the hulls, and the deck as a stack by LAUNCH.
## Why: docs/why/ChassisSelect.md#what-a-ship-comes-with

## The small font's line pitch in a wrapped label, measured off the renders.
const LINE := 13
## The line spacing that brings a wrapped perk's lines to the parts' 11 px pitch.
const PERK_SPACING := 0
## The FITTED column's left edge: 32 px after the attribute values (Jon, Nov 12:
## "move the fitted block to the left a bit"), so the names and the perk have room.
const FIT_X := 504
## The card stack's place, left of LAUNCH and a little off it (Jon, Nov 13: "nudge the cards over to the left").
const STACK_AT := Vector2(694, 438)
## A still can hold the deck spread out (`YardStandsShot deckopen`).
static var hold_open := false


## The deck the fitted parts put in it, in fitting order, each card knowing its part.
static func deck() -> Array[CardData]:
	var out: Array[CardData] = []
	for m: ModuleData in Run.installed:
		for c in m.resolved_cards():
			if c.source_id == &"":
				c.source_id = m.id
			out.append(c)
	return out


# ------------------------------------------------------------------ the band

## The left column: the hull's name, the maker's emblem and name, its slogan and
## (picked) how its parts play, or (pointed at) what a click does; the weight.
static func left_column(band: YardBand, m: ManufacturerData, chosen: bool) -> void:
	var x := YardBand.COL_L
	var w := YardBand.COL_A - YardBand.COL_L - 12
	band._word(Run.hull.name.to_upper(), UITheme.FS_HEAD, x, YardBand.ROW0, YardBand.MINT)
	var y := YardBand.ROW0 + 24
	var em := Emblem.new()
	em.maker = m
	em.position = Vector2(x, y - 1)
	band._words.add_child(em)
	band._word(m.name.to_upper(), UITheme.FS_SMALL, x + 14, y, m.colour)
	var tag := band._word("\"%s\"" % m.tagline.to_upper(), UITheme.FS_SMALL, x, y + 13, YardBand.COLD)
	_wrap(tag, w)
	y = bottom(tag)
	if chosen:
		var how := band._word(m.identity.to_upper(), UITheme.FS_SMALL, x, y + 2, YardBand.ICE)
		_wrap(how, w)
		y = bottom(how)
	else:
		band._word("CLICK TO MAKE IT YOURS", UITheme.FS_SMALL, x, y + 2, YardBand.MINT_DIM)
		y += 14
	var weight := band._word("%s HULL" % HullData.weight_name(Run.hull.weight).to_upper(), UITheme.FS_SMALL, x, y + 1, YardBand.COLD)
	weight.mouse_filter = Control.MOUSE_FILTER_PASS
	weight.tooltip_text = Widgets.tip("%s\n%s" % [HullData.weight_name(Run.hull.weight),
		ChassisSelect.WEIGHT_BLURB[int(Run.hull.weight)]])


## The hardpoint column, spelled out: each fitted part and its slot, the mounts
## left, the hand and the deck, and the hull's perk; the deck's stack by LAUNCH.
static func fitted_column(band: YardBand, m: ManufacturerData) -> void:
	var x := FIT_X
	var w := int(STACK_AT.x) - x - 6
	band._word("FITTED", UITheme.FS_SMALL, x, YardBand.ROW0 - 4, YardBand.COLD)
	var row := YardBand.ROW0 + 8
	for p: ModuleData in Run.installed:
		var nm := band._word(p.name.to_upper(), UITheme.FS_SMALL, x, row, YardBand.ICE)
		nm.mouse_filter = Control.MOUSE_FILTER_PASS
		nm.tooltip_text = Widgets.tip("%s\nA %s part. It puts %d cards in the deck." % [p.name,
			ModuleData.slot_name(p.slot).to_lower(), p.grant_count()])
		band._word(ModuleData.slot_name(p.slot).to_upper(), UITheme.FS_SMALL, x + 120, row, YardBand.COLD)
		row += 11
	var free := 0
	for s: ModuleData.Slot in YardBand.SLOTS:
		free += Run.slots_for(s) - Run.slots_used(s)
	# (on the heading's row: a light with six parts and a long perk ran out of the band)
	band._word("NO MOUNTS FREE" if free == 0 else ("1 MOUNT FREE" if free == 1 else "%d MOUNTS FREE" % free),
		UITheme.FS_SMALL, x + 52, YardBand.ROW0 - 4, YardBand.COLD)
	row += 1
	var hand := band._word("HAND SIZE: %d A TURN" % Run.hand_size(), UITheme.FS_SMALL, x, row, YardBand.ICE)
	hand.mouse_filter = Control.MOUSE_FILTER_PASS
	hand.tooltip_text = Widgets.tip(str(ChassisSelect.MOUNT_TIP["hand"]))
	# (no deck line: the stack says it, Jon: "Deck 10 cards is redundant")
	var strip := DeckStrip.new()
	band._words.add_child(strip)
	var st := DeckStack.new()
	st.maker = m
	st.n = Run.deck_size()
	st.position = STACK_AT
	band._words.add_child(st)
	st.mouse_entered.connect(func() -> void: strip.show_deck(true))
	st.mouse_exited.connect(func() -> void: strip.show_deck(false))
	if hold_open:
		strip.show_deck(true)
	var perk: Dictionary = DB.hull_perks.get(Run.hull.perk_id, {})
	if not perk.is_empty():
		var pk := band._word("%s: %s" % [String(perk.name).to_upper(), String(perk.text).to_upper().trim_suffix(".")],
			UITheme.FS_SMALL, x, row + 11, YardBand.COLD)
		_wrap(pk, w)
		# its second line at the column's own pitch, not the label's looser one
		pk.add_theme_constant_override(&"line_spacing", PERK_SPACING)


static func _wrap(l: Label, w: int) -> void:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(w, 0)
	l.size = Vector2(w, l.size.y)


## The row under a wrapped label's last line (its own count is not laid out yet).
static func bottom(l: Label) -> int:
	return int(l.position.y) + lines(l.text, int(l.custom_minimum_size.x)) * LINE


## How many lines `s` takes at `w` in the small pixel font.
static func lines(s: String, w: int) -> int:
	var f := UITheme.pixel_font()
	var n := 1
	var line := ""
	for word in s.to_upper().split(" "):
		var t := word if line == "" else line + " " + word
		if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x > float(w):
			n += 1
			line = word
		else:
			line = t
	return n


class Emblem extends Control:
	var maker: ManufacturerData

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(11, 11)

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 11, 11), maker.field, true)
		CardView.draw_emblem(self, maker.id, Vector2(5.5, 5.5), 1.0, maker.colour, maker.field)


## The deck as a small stack of card backs; pointing at it spreads it (`DeckStrip`).
class DeckStack extends Control:
	var maker: ManufacturerData
	var n := 10

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		size = Vector2(44, 52)

	func _draw() -> void:
		for i in 3:
			var r := Rect2(4 + i * 5, 2 + (2 - i) * 2, 24, 34)
			draw_rect(r, Color8(22, 26, 34), true)
			draw_rect(r.grow(-1), maker.field.darkened(0.3), true)
			draw_rect(r, maker.colour.darkened(0.2), false, 1.0)
		CardView.draw_emblem(self, maker.id, Vector2(26.5, 21.5), 1.0, maker.colour, maker.field)
		draw_string(UITheme.pixel_font(), Vector2(0, 50), "%d CARDS" % n, HORIZONTAL_ALIGNMENT_LEFT, -1,
			UITheme.FS_SMALL, YardBand.MINT)


## The starting deck laid out over the floor, every card at the hand's size, fanned.
class DeckStrip extends Control:
	const STEP := 84
	var _built := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func show_deck(on: bool) -> void:
		if on and not _built:
			_built = true
			var cards := YardInfo.deck()
			var x0 := (960 - (CardView.CARD_W + STEP * (cards.size() - 1))) / 2
			for i in cards.size():
				var cv := CardView.new()
				cv.setup(cards[i], true, 1)
				cv.position = Vector2(x0 + i * STEP, 236)
				add_child(cv)
				YardInfo._ignore(cv)
		visible = on


static func _ignore(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore(c)


# ------------------------------------------------------------------ the hulls

## The fitted weapons drawn on a hull standing in the yard (`MountPoints`, passive).
static func mount(view: ShipView, hull: HullData, kit: Array[ModuleData]) -> MountPoints:
	var pts := MountPoints.new()
	pts.ship = hull
	pts.fitted = kit
	view.add_child(pts)
	pts.attach(view)
	pts.passive()
	pts.use_parent_material = true
	pts.refresh()
	return pts


## What a chassis launches with, fitted on `Run` for a moment and put back.
static func kit_for(m: StringName, w: HullData.Weight, tier: int) -> Array[ModuleData]:
	var hull := Run.hull
	var was := Run.installed.duplicate()
	var hp := Run.hp
	Run.fit_chassis(m, w, tier)
	var out: Array[ModuleData] = []
	out.assign(Run.installed)
	Run.hull = hull
	Run.installed.assign(was)
	Run.hp = hp
	return out


## The sharp copy's weapons where the hull is this frame (LAUNCH's lift flies it).
static func follow(ghost: Control, s: YardStandSet) -> void:
	if s._view == null:
		return
	for c in ghost.get_children():
		if c is MountPoints:
			var at := s._view.global_position - ghost.global_position
			if (c as Control).position != at:
				(c as Control).position = at
				(c as MountPoints).refresh()


## The sharp copy over the blur carries the picked ship's weapons too.
static func ghost_mounts(ghost: Control, s: YardStandSet) -> void:
	for c in ghost.get_children():
		c.queue_free()
	if s == null or s.mounts == null or not is_instance_valid(s.mounts) or s._view == null:
		return
	var pts := MountPoints.new()
	pts.ship = s.mounts.ship
	pts.fitted = s.mounts.fitted
	ghost.add_child(pts)
	pts.attach(s._view)
	pts.passive()
	pts.use_parent_material = true
	pts.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pts.position = s._view.global_position - ghost.global_position
	pts.size = s._view.size
	pts.refresh()
