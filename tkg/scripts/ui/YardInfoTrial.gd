class_name YardInfoTrial
extends RefCounted

## TRIAL ONLY (Jon, Nov 12: "show the manufacturer information", "show the installed
## modules... they do come with a standard deck of cards"): three ways, by
## `-- yardinfo=B1|B2|B3` (and `deckopen` to hold the deck view open for a still).

const PANEL := Color8(14, 18, 24)
const EDGE := Color8(60, 130, 110)


static func opt() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("yardinfo="):
			return a.substr(9)
	return ""


static func held_open() -> bool:
	return OS.get_cmdline_user_args().has("deckopen")


## The deck the fitted parts put in it, in fitting order.
static func deck() -> Array[CardData]:
	var out: Array[CardData] = []
	for m: ModuleData in Run.installed:
		for c in m.resolved_cards():
			if c.source_id == &"":
				c.source_id = m.id
			out.append(c)
	return out


# ------------------------------------------------------------------ the maker

## The maker's block: emblem and name, its slogan, and how its parts play.
## Returns the row under the last line.
static func maker_block(band: YardBand, m: ManufacturerData, x: int, y: int, w: int) -> int:
	var em := Emblem.new()
	em.maker = m
	em.position = Vector2(x, y - 1)
	band._words.add_child(em)
	band._word(m.name.to_upper(), UITheme.FS_SMALL, x + 14, y, m.colour)
	var tag := band._word("\"%s\"" % m.tagline.to_upper(), UITheme.FS_SMALL, x, y + 13, YardBand.COLD)
	_wrap(tag, w)
	var how := band._word(m.identity.to_upper(), UITheme.FS_SMALL, x, _bottom(tag) + 2, YardBand.ICE)
	_wrap(how, w)
	return _bottom(how)


## The row under a (wrapped) label's last line.
static func _bottom(l: Label) -> int:
	# (a label's own line count is not laid out yet when the band is built: measure the words)
	return int(l.position.y) + _lines(l.text, int(l.custom_minimum_size.x)) * LINE


## The small font's line pitch in a wrapped label, measured off the renders.
const LINE := 13


static func _wrap(l: Label, w: int) -> void:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(w, 0)
	l.size = Vector2(w, l.size.y)


## How many lines `s` takes at `w` in the small pixel font.
static func _lines(s: String, w: int) -> int:
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


# ------------------------------------------------------------------ B1: in the band

## The hardpoint column as what is fitted: each part with a small picture, the
## mounts left, the hand and the deck (pointing at the deck lays it out).
static func fitted_column(band: YardBand, x: int, y: int) -> void:
	band._word("FITTED", UITheme.FS_SMALL, x, y - 4, YardBand.COLD)
	var row := y + 8
	for m: ModuleData in Run.installed:
		var ic := PartIcon.new()
		ic.module = m
		ic.position = Vector2(x, row - 1)
		band._words.add_child(ic)
		var nm := band._word(m.name.to_upper(), UITheme.FS_SMALL, x + 14, row, YardBand.ICE)
		nm.mouse_filter = Control.MOUSE_FILTER_PASS
		nm.tooltip_text = Widgets.tip("%s\n%s part. Puts %d cards in the deck." % [m.name, ModuleData.slot_name(m.slot), m.grant_count()])
		band._word(ModuleData.slot_name(m.slot).to_upper(), UITheme.FS_SMALL, x + 134, row, YardBand.COLD)
		row += 10
	var free := 0
	for s: ModuleData.Slot in YardBand.SLOTS:
		free += Run.slots_for(s) - Run.slots_used(s)
	band._word("NO MOUNTS FREE" if free == 0 else ("1 MOUNT FREE" if free == 1 else "%d MOUNTS FREE" % free), UITheme.FS_SMALL, x, row + 1, YardBand.COLD)
	row += 13
	band._word("HAND %d A TURN" % Run.hand_size(), UITheme.FS_SMALL, x, row, YardBand.ICE)
	var dk := band._word("DECK %d CARDS" % Run.deck_size(), UITheme.FS_SMALL, x + 92, row, YardBand.MINT)
	dk.mouse_filter = Control.MOUSE_FILTER_PASS
	_strip_on(band, dk)
	var perk: Dictionary = DB.hull_perks.get(Run.hull.perk_id, {})
	if not perk.is_empty():
		var pk := band._word("%s: %s" % [String(perk.name).to_upper(), String(perk.text).to_upper().trim_suffix(".")],
			UITheme.FS_SMALL, x, row + 12, YardBand.COLD)
		# (to the grade chips' edge: a long perk ran into the first one)
		_wrap(pk, YardBand.CHIPS_AT.x - x - 8)


## The deck's fan, opened while `over` is pointed at.
static func _strip_on(band: YardBand, over: Control) -> void:
	var strip := DeckStrip.new()
	band._words.add_child(strip)
	over.mouse_entered.connect(func() -> void: strip.show_deck(true))
	over.mouse_exited.connect(func() -> void: strip.show_deck(false))
	if held_open():
		strip.show_deck(true)


## The band for the trial: the maker's block on the left (all three keep the
## band; B3 adds the dossier), the fitted column (B1) or the deck stack (B2).
static func band_ship(band: YardBand, m: ManufacturerData, chosen: bool) -> void:
	var o := opt()
	var y := ROW0
	band._word(Run.hull.name.to_upper(), UITheme.FS_HEAD, YardBand.COL_L, y, YardBand.MINT)
	var next := maker_block(band, m, YardBand.COL_L, y + 24, YardBand.COL_A - YardBand.COL_L - 12) if o != "B3" else y + 24
	if o == "B3":
		band._word(m.name.to_upper(), UITheme.FS_SMALL, YardBand.COL_L, next, YardBand.COLD)
		next += 12
	band._word("%s HULL" % HullData.weight_name(Run.hull.weight).to_upper(), UITheme.FS_SMALL, YardBand.COL_L, next + 2, YardBand.COLD)
	if not chosen:
		band._word("CLICK TO MAKE IT YOURS", UITheme.FS_SMALL, YardBand.COL_L, next + 14, YardBand.MINT_DIM)
	if o == "B2":
		var st := DeckStack.new()
		st.maker = m
		st.n = Run.deck_size()
		st.position = Vector2(706, 438)
		band._words.add_child(st)
		_strip_on(band, st)


const ROW0 := YardBand.ROW0


## B2: the sharp copy over the blur carries the fitted weapons too.
static func ghost_mounts(ghost: Control, s: YardStandSet) -> void:
	for c in ghost.get_children():
		c.queue_free()
	if s == null or not s.has_meta(&"mounts") or s._view == null:
		return
	var src: MountPoints = s.get_meta(&"mounts")
	if not is_instance_valid(src):
		return
	var pts := MountPoints.new()
	pts.ship = src.ship
	pts.fitted = src.fitted
	ghost.add_child(pts)
	pts.attach(s._view)
	pts.passive()
	pts.use_parent_material = true
	pts.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pts.position = s._view.global_position - ghost.global_position
	pts.size = s._view.size
	pts.refresh()


## B3: the dossier for the ship pointed at or picked, or none.
static func dossier(cs: Control, m: ManufacturerData, weight: int) -> void:
	if opt() != "B3":
		return
	var d := cs.get_node_or_null(^"Dossier") as Dossier
	if weight < 0:
		if d != null:
			d.queue_free()
		return
	if d == null:
		d = Dossier.new()
		d.name = "Dossier"
		cs.add_child(d)
	d.fill(m, weight)
	d.queue_redraw()


## A part's picture shrunk into a 12 x 8 box (whole pixels, nearest).
class PartIcon extends Control:
	var module: ModuleData

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(12, 9)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		var t := DB.module_sprite(module.id)
		var md: ManufacturerData = DB.manufacturers.get(module.manufacturer)
		draw_rect(Rect2(0, 0, 12, 9), Color8(30, 36, 44), true)
		draw_rect(Rect2(0, 0, 12, 9), md.colour if md != null else YardBand.COLD, false, 1.0)
		if t != null:
			var k := minf(10.0 / float(t.get_width()), 7.0 / float(t.get_height()))
			var s := (Vector2(t.get_size()) * k).floor().max(Vector2.ONE)
			draw_texture_rect(t, Rect2(((size - s) * 0.5).floor(), s), false)


## The starting deck laid out over the floor: every card at the hand's size, fanned.
class DeckStrip extends Control:
	const STEP := 84
	var _cards: Array[CardView] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func show_deck(on: bool) -> void:
		if on and _cards.is_empty():
			var cards := YardInfoTrial.deck()
			var w := CardView.CARD_W + STEP * (cards.size() - 1)
			var x0 := (960 - w) / 2
			for i in cards.size():
				var cv := CardView.new()
				cv.setup(cards[i], true, 1)
				cv.position = Vector2(x0 + i * STEP, 236)
				add_child(cv)
				YardInfoTrial._ignore(cv)
				_cards.append(cv)
		visible = on


static func _ignore(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore(c)


# ------------------------------------------------------------------ B2: on the ship

## The deck as a small stack of card backs beside LAUNCH; pointing at it spreads it.
class DeckStack extends Control:
	var maker: ManufacturerData
	var n := 10
	var strip: DeckStrip

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
		var f := UITheme.pixel_font()
		var s := "%d CARDS" % n
		draw_string(f, Vector2(0, 50), s, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, YardBand.MINT)


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


## What `w` launches with, fitted on `Run` for a moment and put back.
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


# ------------------------------------------------------------------ B3: the dossier

## A slim plate out of the lower left (the right, for the light, which stands
## there): the maker, what is fitted with the weapon's picture, the deck as tiles.
class Dossier extends Control:
	const W := 236
	const H := 196
	var band: YardBand

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(W, H)

	func fill(m: ManufacturerData, weight: int) -> void:
		for c in get_children():
			c.queue_free()
		var right := weight == int(HullData.Weight.LIGHT)
		var to_x := 960.0 - W - 8.0 if right else 8.0
		var key := "%s|%d" % [m.id, weight]
		if get_meta(&"key", "") != key:
			# (slides out once per ship, not again on every refresh of the band)
			set_meta(&"key", key)
			position = Vector2(to_x + (W if right else -W), 194)
			var tw := create_tween()
			tw.tween_property(self, ^"position:x", to_x, 0.0 if YardInfoTrial.held_open() else 0.18)
		var em := YardInfoTrial.Emblem.new()
		em.maker = m
		em.position = Vector2(10, 9)
		add_child(em)
		_w(m.name.to_upper(), 24, 10, m.colour)
		var y := YardInfoTrial._bottom(_w(m.identity.to_upper(), 10, 24, YardBand.ICE, W - 20)) + 6
		_w("STARTS WITH", 10, y, YardBand.COLD)
		y += 12
		var weapon: ModuleData = null
		var rest: Array[String] = []
		for p: ModuleData in Run.installed:
			if weapon == null and p.manufacturer == m.id:
				weapon = p
			else:
				rest.append(p.name.to_upper())
		if weapon != null:
			var t := DB.module_sprite(weapon.id)
			if t != null:
				var tr := TextureRect.new()
				tr.texture = t
				tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				tr.position = Vector2(10, y)
				tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(tr)
				_w(weapon.name.to_upper(), 16 + t.get_width(), y + t.get_height() / 2 - 4, m.colour)
				y += maxi(t.get_height(), 10) + 4
		y = YardInfoTrial._bottom(_w(", ".join(rest), 10, y, YardBand.ICE, W - 20)) + 6
		var cards := YardInfoTrial.deck()
		_w("STARTING DECK, %d CARDS" % cards.size(), 10, y, YardBand.COLD)
		y += 12
		for i in cards.size():
			var tile := CardTile.new()
			tile.card = cards[i]
			tile.position = Vector2(10 + (i % 5) * 44, y + (i / 5) * 32)
			add_child(tile)
		size.y = y + ((cards.size() + 4) / 5) * 32 + 6

	func _w(s: String, x: int, y: int, col: Color, wrap: int = 0) -> Label:
		var l := UITheme.body(s, col, UITheme.FS_SMALL)
		l.position = Vector2(x, y)
		add_child(l)
		if wrap > 0:
			YardInfoTrial._wrap(l, wrap)
		return l

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, YardInfoTrial.PANEL, true)
		draw_rect(r.grow(-1), Color8(20, 26, 34), true)
		draw_rect(r, YardInfoTrial.EDGE, false, 1.0)
		draw_rect(Rect2(2, 2, size.x - 4, 1), Color8(40, 70, 64), true)


## One starting card as a tile: its maker's stripe, its cost, its part's picture.
class CardTile extends Control:
	var card: CardData

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(42, 30)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		var md: ManufacturerData = DB.manufacturers.get(card.manufacturer)
		var mark: Color = md.colour if md != null else YardBand.COLD
		draw_rect(Rect2(Vector2.ZERO, size), Color8(34, 40, 50), true)
		draw_rect(Rect2(0, 0, 2, size.y), mark, true)
		draw_rect(Rect2(Vector2.ZERO, size), Color8(90, 100, 116), false, 1.0)
		var t := DB.module_sprite(card.source_id)
		if t != null:
			var k := minf(28.0 / float(t.get_width()), 24.0 / float(t.get_height()))
			k = floorf(k) if k >= 1.0 else k
			var s := (Vector2(t.get_size()) * k).floor().max(Vector2.ONE)
			draw_texture_rect(t, Rect2(Vector2(12, 3) + ((Vector2(28, 24) - s) * 0.5).floor(), s), false)
		var f := UITheme.pixel_font()
		draw_rect(Rect2(3, 2, 8, 9), Color8(20, 24, 30), true)
		draw_string(f, Vector2(5, 10), str(card.energy), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, YardBand.ICE)
