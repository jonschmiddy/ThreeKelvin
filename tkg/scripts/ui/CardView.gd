class_name CardView
extends Control

## Inspect is an exact 2x of hand so the furniture stays on a true pixel grid.
## One corner, one meaning: energy top-left is the cost, heat top-right the byproduct.
## Why: docs/why/CardView.md#card-scale-and-corners

signal chosen(view: CardView)
## The press carries its own point: the OS cursor is not where a pushed event happened.
## Why: docs/why/CardView.md#grab-gesture
signal grabbed(view: CardView, at: Vector2)
signal hovered(view: CardView, entered: bool)
## The pointer on one of the card's keywords, or off it (T2): the word lights, its tag shows.
signal word_hovered(view: CardView, term: String, on: bool)

## Hand width 112, with the gain going to the content column. Five cards still fit 640.
## Why: docs/why/CardView.md#card-size
const CARD_W := 112
## Height 160 gives the art room; width is the constrained axis, height has the slack.
## Why: docs/why/CardView.md#card-size
const CARD_H := 160

## Reading order is cost, name, picture. The banner is odd width so marks centre on a pixel.
## Why: docs/why/CardView.md#zone-map
const Z_BANNER := Rect2(2, 1, 13, 158)      ## the manufacturer, full height, left edge
const Z_ENERGY := Rect2(16, 3, 13, 13)      ## what you pay
const Z_HEAT := Rect2(96, 3, 13, 13)        ## what it leaves behind
## Two lines: Suppressing Fire ran off the card on one, and two-word verbs are common.
## Why: docs/why/CardView.md#zone-map
const Z_NAME := Rect2(16, 18, 93, 22)       ## the verb
const Z_ART := Rect2(16, 42, 93, 60)        ## the granting module's sprite
## Eleven tall: an 8px font plus leading overran nine and ATTACK printed over the text box.
## Placed from the ink, not the box, as the font leaves its bottom two rows empty.
## Why: docs/why/CardView.md#type-line-zone
const Z_TYPE := Rect2(16, 106, 93, 11)       ## type + lane
## The text box runs to the card's bottom: no provenance footer, the module is in the readout.
const Z_TEXT := Rect2(16, 119, 93, 39)

var card: CardData
var playable: bool = true

var _s: int = 1
var _tween: Tween
var _base_y: float = 0.0
var _tint: Color = UITheme.CHILL

## The effect label, kept so the number on it can change without a rebuild.
var _body: RichTextLabel = null

## Pushed by the hand, default -1, so gallery cards cannot pick up live numbers by accident.
## Why: docs/why/CardView.md#live-output
var live_output: int = -1

## Which of its own clauses are paying, by keyword -- see `Combat.card_hot`.
var live_hot: PackedStringArray = PackedStringArray()


## Returns at once unless the number moved: a hand is five to seven rich-text relayouts.
func set_live(n: int, hot: PackedStringArray = PackedStringArray()) -> void:
	# Compare both: the number can hold while the paying clause swaps, lighting the wrong one.
	if n == live_output and hot == live_hot:
		return
	live_output = n
	live_hot = hot
	_refresh_body()


## The word under the pointer, lit on the card (T2).
var lit_word := ""


func _refresh_body() -> void:
	if _body != null and card != null:
		_body.text = card.describe_rich(live_output, live_hot, lit_word)


## The pointer moving over the text: the keyword under it lights, the one it left goes out.
func _on_body_input(e: InputEvent) -> void:
	var mm := e as InputEventMouseMotion
	if mm == null:
		return
	var t := word_at(mm.position)
	if t == lit_word:
		return
	if lit_word != "":
		_on_word(lit_word, false)
	if t != "":
		_on_word(t, true)


## Which keyword sits under `p` (the body's own coordinates), or "". Measured with a
## `TextParagraph` shaped as the body is, not the label's meta hover, which never fired for
## a pushed motion over the hand; the same measure works headless.
## Why: docs/why/CardView.md#word-under-the-pointer
func word_at(p: Vector2) -> String:
	if _body == null or card == null:
		return ""
	var text := _body.get_parsed_text()
	var para := TextParagraph.new()
	para.width = _body.size.x
	para.add_string(text, UITheme.pixel_font(), UITheme.FS_SMALL * _s)
	if p.x < 0.0 or p.y < 0.0 or p.x > _body.size.x or p.y > para.get_size().y:
		return ""
	var idx := para.hit_test(p)
	for raw in card.keywords():
		var term := String((raw as Array)[0])
		var i := text.find(term)
		while i >= 0:
			if idx >= i and idx < i + term.length():
				return term
			i = text.find(term, i + 1)
	return ""


func _on_word(meta: Variant, on: bool) -> void:
	var term := String(meta)
	var now := term if on else ""
	if now == lit_word and on:
		return
	# a word left while another is already lit: that one stays
	if not on and lit_word != term:
		return
	lit_word = now
	_refresh_body()
	word_hovered.emit(self, term, on)


func setup(c: CardData, can_play: bool, scale_step: int = 1) -> void:
	card = c
	playable = can_play
	_s = maxi(1, scale_step)
	_tint = DB.manufacturer_colour(c.manufacturer)
	custom_minimum_size = Vector2(CARD_W * _s, CARD_H * _s)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP

	Widgets.clear(self)

	# Name shows at both scales and carries rarity, as effect text is unreadable at 96px.
	# Why: docs/why/CardView.md#name-and-rarity
	var nm := UITheme.body(c.name, ModuleData.rarity_ink(c.source_rarity),
		UITheme.FS_SMALL * _s)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.clip_text = true
	# Godot adds line spacing, so Fire clipped off the bottom. Tighten it and size the plate.
	nm.add_theme_constant_override("line_spacing", 0)
	# Centred in the plate: it is sized for two lines and most verbs are one.
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(nm, Z_NAME, 2)
	var ty := UITheme.body(_type_line(), UITheme.COLD, UITheme.FS_SMALL * _s)
	ty.add_theme_constant_override("line_spacing", 0)
	_place(ty, Z_TYPE, 2)

	# Shown at both scales: 8px Silkscreen is the whole UI's body font, so it is readable.
	# Keywords are underlined and lifted to ICE: two channels, so colourblind readers still see it.
	# Why: docs/why/CardView.md#effect-text
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# PASS, not IGNORE: the words answer the pointer (T2), and clicks still reach the card.
	# The card counts the body's hover as its own, so the lift is not lost over the text.
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	body.meta_underlined = false
	body.gui_input.connect(_on_body_input)
	body.mouse_exited.connect(func() -> void:
		if lit_word != "":
			_on_word(lit_word, false))
	mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
	body.add_theme_font_override("normal_font", UITheme.pixel_font())
	body.add_theme_font_size_override("normal_font_size", UITheme.FS_SMALL * _s)
	body.add_theme_color_override("default_color", UITheme.CHILL)
	body.add_theme_constant_override("line_separation", 0)
	_body = body
	body.text = c.describe_rich(live_output, live_hot, lit_word)
	body.position = Vector2((Z_TEXT.position.x + 2) * _s, Z_TEXT.position.y * _s)
	body.size = Vector2((Z_TEXT.size.x - 4) * _s, Z_TEXT.size.y * _s)
	add_child(body)
	set_playable(can_play)
	queue_redraw()

func _place(l: Label, zone: Rect2, inset: int) -> void:
	l.position = Vector2(zone.position.x * _s + inset * _s, zone.position.y * _s)
	l.size = Vector2(zone.size.x * _s - inset * 2 * _s, zone.size.y * _s)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)

## The lane is the verb-pool key, so it prints even on an unbranded card for set-bonus play.
func _type_line() -> String:
	var lane := String(card.lane)
	if lane == "":
		return card.type_name().to_upper()
	return "%s · %s" % [card.type_name().to_upper(), lane.to_upper()]

## Opt-in via tooltip_text: the hand and gallery build their own readouts and must not get two.
## Why: docs/why/CardView.md#native-tooltip
func _make_custom_tooltip(_for_text: String) -> Object:
	if card == null:
		return null
	# Never in a hand: it builds this panel itself, and a native copy would float at the cursor.
	# Why: docs/why/CardView.md#native-tooltip
	if get_parent() is HandView:
		return null
	return Widgets.card_readout(card)

func _draw() -> void:
	var s := float(_s)
	var w := CARD_W * s
	var h := CARD_H * s
	var dim := card.unplayable

	# Frame. A malfunction is dead weight and has to LOOK like dead weight in
	# the fan, before you read a word of it.
	draw_rect(Rect2(0, 0, w, h), Color("#1a1418") if dim else UITheme.PANEL2, true)
	draw_rect(Rect2(0, 0, w, h), UITheme.LINE, false, s)

	# Manufacturer is colour, emblem and cut; type is structure, so the two channels never share.
	if dim:
		# A bare edge was the one junk signal made of an absence and read as a card half drawn.
		# Why: docs/why/CardView.md#malfunction-banner
		_junk_banner()
	else:
		_banner()

	# The real cost shows: junk is Patchable, so a dashed corner would tell a lie.
	_gem(_z(Z_ENERGY), str(card.energy), UITheme.ICE)
	_gem(_z(Z_HEAT), _heat_text(), UITheme.EMBER if card.net_heat() >= 0 else UITheme.GOOD)

	# Art window. Recessed, one shade darker, so vector type over it stays legible.
	var art := _z(Z_ART)
	draw_rect(art, UITheme.VOID, true)
	draw_rect(art, UITheme.LINE, false, 1.0 * s)
	# No hatch over the art: it blanked or ate the art of all sixteen malfunctions.
	# Why: docs/why/CardView.md#malfunction-art
	if not _draw_art(art):
		_type_glyph()

	# Plates draw at both scales: the furniture is one layout, so hiding one leaves a hole.
	# Why: docs/why/CardView.md#recessed-plates
	_plate(_z(Z_NAME))
	_plate(_z(Z_TEXT))

	# Charge pips are state, so they get structure, not text, along the art's bottom edge.
	if card.charge_turns > 0:
		var px := (Z_ART.position.x + 2) * s
		var py := (Z_ART.end.y - 4) * s
		for i in card.charge_turns:
			draw_rect(Rect2(px + i * 6.0 * s, py, 4.0 * s, 2.0 * s), UITheme.FLARE, true)

	# Rarity is the name's colour and the module is in the readout, freeing a row for effect text.
	# Why: docs/why/CardView.md#rarity-and-provenance

	# Pointed at: the one outline (C1); armed: the same frame in the aim's own orange, one with
	# the wavy line and the brackets (Jon, Nov 9).
	if marked:
		MarkOutline.draw_rect_mark(self, Rect2(0, 0, w, h), UITheme.MARK_PX * s,
			UITheme.FLARE if armed else UITheme.MARK)

## A banner is identity: ground, mark and hem. The hem survives with no colour at all.
## A malfunction has no mark, as nobody built it and an emblem would invent an allegiance.
## Why: docs/why/CardView.md#manufacturer-banner
func _junk_banner() -> void:
	var s := float(_s)
	var b := _z(Z_BANNER)
	var mark := UITheme.LEAVE
	# Dark enough to sit behind the frame: a card you would rather not hold must not shout.
	draw_rect(b, mark.lerp(UITheme.VOID, 0.62), true)
	_cut(b, mark)

	# The mark is a break, as in SYSTEM REPAIR, at emblem height so a fan lines up.
	# Why: docs/why/CardView.md#malfunction-banner
	var cx := b.position.x + b.size.x * 0.5
	var cy := (Z_ENERGY.position.y + Z_ENERGY.size.y * 0.5) * s
	draw_rect(Rect2(cx - 4.0 * s, cy - 4.0 * s, 4.0 * s, 2.0 * s), mark)
	draw_rect(Rect2(cx, cy + 2.0 * s, 4.0 * s, 2.0 * s), mark)
	draw_rect(Rect2(cx - 1.0 * s, cy - 1.0 * s, 2.0 * s, 3.0 * s), mark)

	# Same outline as every banner, last, in four filled rects. See `_banner` for why.
	var edge := mark.darkened(0.3)
	draw_rect(Rect2(b.position.x, b.position.y, s, b.size.y), edge, true)
	draw_rect(Rect2(b.end.x - s, b.position.y, s, b.size.y), edge, true)
	draw_rect(Rect2(b.position.x, b.position.y, b.size.x, s), edge, true)
	draw_rect(Rect2(b.position.x, b.end.y - s, b.size.x, s), edge, true)


func _banner() -> void:
	var s := float(_s)
	var manufacturer: ManufacturerData = DB.manufacturers.get(card.manufacturer)
	var b := _z(Z_BANNER)
	var field := manufacturer.field if manufacturer != null else UITheme.PANEL
	var mark := manufacturer.colour if manufacturer != null else UITheme.COLD
	draw_rect(b, field, true)
	_cut(b, mark)
	# Centre comes from the banner: a hardcoded 9 against a real 9.5 left marks half a pixel off.
	# Why: docs/why/CardView.md#emblem-centring
	_emblem(Vector2(b.position.x + b.size.x * 0.5,
		(Z_ENERGY.position.y + Z_ENERGY.size.y * 0.5) * s), mark, field)
	# Every banner is outlined last in four filled rects: some fields match the card colour.
	# Why: docs/why/CardView.md#banner-outline
	var edge := mark.darkened(0.3)
	draw_rect(Rect2(b.position.x, b.position.y, s, b.size.y), edge, true)
	draw_rect(Rect2(b.end.x - s, b.position.y, s, b.size.y), edge, true)
	draw_rect(Rect2(b.position.x, b.position.y, b.size.x, s), edge, true)
	draw_rect(Rect2(b.position.x, b.end.y - s, b.size.x, s), edge, true)

## Carve the bottom edge into the manufacturer's shape by painting the card back over
## it. Cheaper than authoring seven polygons and it stays on the pixel grid.
func _cut(b: Rect2, mark: Color) -> void:
	draw_cut(self, card.manufacturer, b, mark, UITheme.PANEL2, float(_s))

## Static so chassis select can draw them at 4x. `back` must be the banner's ground.
## Why: docs/why/CardView.md#banner-hems
static func draw_cut(ci: CanvasItem, manufacturer: StringName, b: Rect2, mark: Color,
		back: Color, s: float) -> void:
	var base := b.end.y

	# All hems draw through a clip, so staying inside the banner is a property of the function.
	var hem := func(r: Rect2, col: Color) -> void:
		var x0 := maxf(r.position.x, b.position.x)
		var y0 := maxf(r.position.y, b.position.y)
		var x1 := minf(r.end.x, b.end.x)
		var y1 := minf(r.end.y, b.end.y)
		if x1 > x0 and y1 > y0:
			ci.draw_rect(Rect2(x0, y0, x1 - x0, y1 - y0), col, true)
	match manufacturer:
		&"solari":
			# Vent slots. A forge hem: the flag ends where the heat gets out.
			hem.call(Rect2(b.position.x, base - 4 * s, b.size.x, 3.0 * s),
				mark.darkened(0.5))
			for i in 3:
				hem.call(Rect2(b.position.x + (2 + i * 4) * s, base - 3 * s,
					s, s), mark)
		&"probate":
			# A bolted lip. Thick plate, big fasteners, done by someone paid by
			# the hour.
			hem.call(Rect2(b.position.x, base - 5 * s, b.size.x, 4.0 * s),
				mark.darkened(0.5))
			for i in 2:
				hem.call(Rect2(b.position.x + (2 + i * 6) * s, base - 4 * s,
					3.0 * s, 2.0 * s), mark)
		&"verity":
			# A hairline seam: two bands with one dark line between them.
			hem.call(Rect2(b.position.x, base - 6 * s, b.size.x, 2.0 * s), mark)
			hem.call(Rect2(b.position.x, base - 4 * s, b.size.x, s), back)
			hem.call(Rect2(b.position.x, base - 3 * s, b.size.x, 2.0 * s), mark)
		&"cygnet":
			# A signal notch — one gap in a plain band, off centre, like a port
			# cut for an aerial.
			hem.call(Rect2(b.position.x, base - 4 * s, b.size.x, 3.0 * s),
				mark.darkened(0.5))
			hem.call(Rect2(b.position.x + 8 * s, base - 4 * s, 2.0 * s, 3.0 * s), back)
			hem.call(Rect2(b.position.x + 8 * s, base - 4 * s, 2.0 * s, s), mark)
		&"calyx":
			# A sealed edge. No fasteners, no seam, no texture — the hem of a
			# thing grown in one piece rather than assembled.
			hem.call(Rect2(b.position.x, base - 5 * s, b.size.x, 4.0 * s), mark)
		&"redline":
			# Redline's hem is drawn, not carved, as its field matches the card. Strips stay low.
			# The first version at sixteen ate the emblem on every card the manufacturer flies.
			# Why: docs/why/CardView.md#banner-hems
			hem.call(Rect2(b.position.x, base - 2 * s, b.size.x, 2.0 * s), mark)
			for i in 6:
				var hh: float = [3, 1, 4, 1, 3, 1][i]
				hem.call(Rect2(b.position.x + i * 2 * s, base - hh * s,
					2.0 * s, hh * s), mark)
			# The two that let go are one unit wide and off the even pitch, as a snag is.
			hem.call(Rect2(b.position.x + 3 * s, base - 8 * s, s, 8.0 * s), mark)
			hem.call(Rect2(b.position.x + 9 * s, base - 6 * s, s, 6.0 * s), mark)
		&"korvan":
			# Flat, with a riveted steel band. Decoration is for people whose
			# guns jam.
			hem.call(Rect2(b.position.x, base - 4 * s, b.size.x, 3.0 * s),
				mark.darkened(0.45))
			for i in 4:
				hem.call(Rect2(b.position.x + (3 + i * 2) * s, base - 3 * s, s, s), mark)
		_:
			# Unbranded: nothing. Precursor tech and grown things have no manufacturer
			# to fly for, and a blank hem says that better than any shape would.
			pass

## Offsets are halves (-6.5 for 13): whole numbers put all seven emblems half a pixel off.
## Why: docs/why/CardView.md#emblem-centring
func _emblem(c: Vector2, mark: Color, field: Color) -> void:
	draw_emblem(self, card.manufacturer, c, float(_s), mark, field)

## Static so the ship tab wears the same emblems; two copies of the offsets would drift.
## Why: docs/why/CardView.md#emblems
static func draw_emblem(ci: CanvasItem, manufacturer: StringName, c: Vector2, s: float,
		mark: Color, field: Color) -> void:
	var r := func(off: Vector2, sz: Vector2, col: Color) -> void:
		ci.draw_rect(Rect2(c + off * s, sz * s), col, true)
	match manufacturer:
		&"korvan":
			# Pitch 4 on whole numbers: a half-pixel gap does not exist and the rasteriser chose.
			# Why: docs/why/CardView.md#emblems
			r.call(Vector2(-4.5, -5), Vector2(9, 2), mark)
			r.call(Vector2(-3.5, -1), Vector2(7, 2), mark)
			r.call(Vector2(-2.5, 3), Vector2(5, 2), mark)
		&"solari":
			# Three rects, not five: opposite rays are collinear, and a bar draws the same.
			# Why: docs/why/CardView.md#emblems
			r.call(Vector2(-0.5, -4.5), Vector2(1, 9), mark)
			r.call(Vector2(-4.5, -0.5), Vector2(9, 1), mark)
			r.call(Vector2(-1.5, -1.5), Vector2(3, 3), mark)
		&"probate":
			# A bucket narrowing to its teeth. The bite is the manufacturer.
			r.call(Vector2(-4.5, -4.5), Vector2(9, 2), mark)
			r.call(Vector2(-3.5, -2.5), Vector2(7, 2), mark)
			r.call(Vector2(-2.5, -0.5), Vector2(5, 2), mark)
			for i in 3:
				r.call(Vector2(-2.5 + i * 2, 2.5), Vector2(1, 2), mark)
		&"redline":
			# The namesake line, severed, still flying.
			r.call(Vector2(-4.5, -1.5), Vector2(4, 3), mark)
			r.call(Vector2(0.5, -1.5), Vector2(4, 3), mark)
		&"verity":
			# Two rules and the hairline between them. Luxury is what you leave
			# off.
			r.call(Vector2(-4.5, -2.5), Vector2(9, 2), mark)
			r.call(Vector2(-4.5, 0.5), Vector2(9, 2), mark)
		&"cygnet":
			# Drone diamond under two signal arcs, one antenna drop.
			r.call(Vector2(-1.5, -0.5), Vector2(3, 3), mark)
			r.call(Vector2(-4.5, -2.5), Vector2(9, 1), mark)
			r.call(Vector2(-3.5, -4.5), Vector2(7, 1), mark)
			r.call(Vector2(-0.5, 2.5), Vector2(1, 2), mark)
		&"calyx":
			# A clinical cross, symmetric on both axes. Nothing that actually
			# grew is this tidy; the wrongness is the point.
			r.call(Vector2(-1.5, -4.5), Vector2(3, 9), mark)
			r.call(Vector2(-4.5, -1.5), Vector2(9, 3), mark)
		_:
			# Unbranded: precursor or grown. A bare punched square.
			r.call(Vector2(-3.5, -3.5), Vector2(7, 7), mark)
			r.call(Vector2(-1.5, -1.5), Vector2(3, 3), field)

## Whole multiples only, as resampling pixel art is refused. A wrong-sized file centres to show it.
## Why: docs/why/CardView.md#card-art
func _draw_art(where: Rect2) -> bool:
	var tex: Texture2D = card.sprite
	if tex == null:
		return false
	var at := where.position + (where.size - Vector2(tex.get_size()) * float(_s)) * 0.5
	draw_texture_rect(tex, Rect2(at.round(),
		Vector2(tex.get_size()) * float(_s)), false)
	return true

## Shape, not colour, as colour is the manufacturer channel. A blank art window sorts nothing.
## Why: docs/why/CardView.md#type-glyphs
func _type_glyph() -> void:
	var s := float(_s)
	var c := Vector2(62, 72) * s          ## centre of the art window, 93 x 60
	var ink := _tint.lightened(0.18)
	var dark := _tint.darkened(0.4)
	match card.glyph_kind():
		&"slug":
			# ONE heavy round, nose right, tracer behind. The silhouette a
			# player should read as "this hits once and it hits hard".
			_round(c + Vector2(-4, 0) * s, 1.0, ink, dark)
			_tracer(c + Vector2(-30, 0) * s, 3, dark)
		&"burst":
			# Deal 2 x 5 is a stream and Deal 40 a hammer. Rounds count to four, then mean a lot.
			# Why: docs/why/CardView.md#type-glyphs
			var n := clampi(card.hits, 2, 4)
			var k := 1.0 - 0.16 * float(n - 2)
			for i in n:
				var x := -30.0 + float(i) * (26.0 - float(n) * 2.0)
				_round(c + Vector2(x, 0) * s, k * 0.72, ink, dark)
		&"pyre":
			# An attack whose number is your heat: the only glyph lit from inside.
			_round(c + Vector2(-2, 0) * s, 1.0, ink, dark)
			_r(c + Vector2(-6, -3) * s, Vector2(14, 6) * s, UITheme.FLARE)
			_r(c + Vector2(-2, -2) * s, Vector2(7, 4) * s, UITheme.HOT)
			for i in 3:
				_r(c + Vector2(-28 + i * 8, -2 - i) * s, Vector2(5, 2) * s, UITheme.EMBER)
		&"charge":
			# A coil banking energy, stacked and rising to a pip that has not
			# gone yet. The one glyph that is about a FUTURE turn.
			for i in 3:
				var w := 30 - i * 6
				_r(c + Vector2(-w * 0.5, -12 + i * 10) * s, Vector2(w, 6) * s,
					ink if i == 0 else dark)
			_r(c + Vector2(-3, -22) * s, Vector2(6, 7) * s, UITheme.FLARE)
			_r(c + Vector2(-1, -27) * s, Vector2(2, 4) * s, UITheme.HOT)
		&"drone":
			# A hull and its escort. Something that fires without you.
			_r(c + Vector2(-5, -5) * s, Vector2(11, 11) * s, ink)
			_r(c + Vector2(-20, -14) * s, Vector2(6, 6) * s, dark)
			_r(c + Vector2(15, 8) * s, Vector2(6, 6) * s, dark)
			_r(c + Vector2(17, -12) * s, Vector2(5, 5) * s, dark)
		&"brace":
			# BRACE: a wall you keep. Thick, bevelled, whole — and unbroken,
			# which is the whole difference from block below.
			_r(c + Vector2(-15, -20) * s, Vector2(30, 40) * s, dark)
			_r(c + Vector2(-11, -16) * s, Vector2(22, 32) * s, ink)
			_r(c + Vector2(-6, -10) * s, Vector2(12, 20) * s, dark)
		&"block":
			# Segmented like Brace: gaps say temporary, and the pair must tell apart at a glance.
			for i in 3:
				_r(c + Vector2(-13, -20 + i * 14) * s, Vector2(26, 10) * s,
					ink if i == 1 else dark)
		&"feedback":
			# Feedback is a wall plus the attack glyph's round, leaving right as damage does.
			# Why: docs/why/CardView.md#type-glyphs
			_r(c + Vector2(-20, -19) * s, Vector2(13, 38) * s, ink)
			_r(c + Vector2(-16, -13) * s, Vector2(5, 26) * s, dark)
			_round(c + Vector2(8, 0) * s, 0.62, ink, dark)
		&"slip":
			# The hit that does not land: a round passing THROUGH the gap where
			# the ship was. Absence, drawn.
			_r(c + Vector2(-14, -20) * s, Vector2(9, 15) * s, dark)
			_r(c + Vector2(-14, 6) * s, Vector2(9, 15) * s, dark)
			_round(c + Vector2(2, 0) * s, 0.8, ink, dark)
			_tracer(c + Vector2(-30, 0) * s, 2, dark)
		&"vent":
			# Heat leaving, through slats. Rising, because that is the direction
			# the player wants it going.
			_r(c + Vector2(-16, 6) * s, Vector2(33, 10) * s, ink)
			for i in 3:
				_r(c + Vector2(-12 + i * 11, -4) * s, Vector2(6, 9) * s, dark)
				_r(c + Vector2(-11 + i * 11, -17 - (i % 2) * 4) * s,
					Vector2(4, 9) * s, UITheme.EMBER)
		&"repair":
			# A seam being closed. Plate, and the weld across it.
			_r(c + Vector2(-16, -14) * s, Vector2(33, 28) * s, dark)
			_r(c + Vector2(-4, -18) * s, Vector2(9, 36) * s, ink)
			_r(c + Vector2(-16, -4) * s, Vector2(33, 9) * s, ink)
		&"lock":
			# Written out, not looped: an L has handedness, and a derived version read as ticks.
			# Why: docs/why/CardView.md#type-glyphs
			var arm := Vector2(11, 3)
			var leg := Vector2(3, 11)
			_r(c + Vector2(-20, -20) * s, arm * s, ink)   ## top left
			_r(c + Vector2(-20, -20) * s, leg * s, ink)
			_r(c + Vector2(9, -20) * s, arm * s, ink)     ## top right
			_r(c + Vector2(17, -20) * s, leg * s, ink)
			_r(c + Vector2(-20, 17) * s, arm * s, ink)    ## bottom left
			_r(c + Vector2(-20, 9) * s, leg * s, ink)
			_r(c + Vector2(9, 17) * s, arm * s, ink)      ## bottom right
			_r(c + Vector2(17, 9) * s, leg * s, ink)
			_r(c + Vector2(-3, -3) * s, Vector2(6, 6) * s, UITheme.HOT)
		&"draw":
			# Cards, one lifted off the pile. Reads as "more hand".
			_r(c + Vector2(-18, -4) * s, Vector2(20, 24) * s, dark)
			_r(c + Vector2(-12, -10) * s, Vector2(20, 24) * s, dark)
			_r(c + Vector2(-4, -20) * s, Vector2(20, 26) * s, ink)
		&"power":
			# A cell with a charge in it.
			_r(c + Vector2(-13, -18) * s, Vector2(26, 36) * s, dark)
			_r(c + Vector2(-9, -14) * s, Vector2(18, 28) * s, ink)
			_r(c + Vector2(-3, -12) * s, Vector2(7, 12) * s, UITheme.FLARE)
			_r(c + Vector2(-3, 1) * s, Vector2(7, 11) * s, UITheme.HOT)
		&"scrip":
			# Stacked notes. The human economy, which is the only kind a card
			# ever pays out in. See docs/lore.md §1.
			for i in 3:
				_r(c + Vector2(-16 + i * 3, -12 + i * 9) * s, Vector2(30, 7) * s,
					ink if i == 2 else dark)
		&"malfunction":
			# Broken used to draw a vent, the most misleading picture of the old set.
			_r(c + Vector2(-16, -4) * s, Vector2(13, 5) * s, dark)
			_r(c + Vector2(1, -12) * s, Vector2(9, 5) * s, dark)
			_r(c + Vector2(-7, 8) * s, Vector2(11, 4) * s, dark)
			_r(c + Vector2(8, 4) * s, Vector2(7, 6) * s, dark)
			_r(c + Vector2(-19, 10) * s, Vector2(6, 4) * s, dark)
		_:
			# Utility with no verb this list knows about. A module housing: a
			# box with a fitting on it, which is what an unclassified part is.
			_r(c + Vector2(-15, -12) * s, Vector2(30, 24) * s, dark)
			_r(c + Vector2(-10, -7) * s, Vector2(20, 14) * s, ink)
			_r(c + Vector2(15, -4) * s, Vector2(7, 8) * s, dark)

## Shared by every attack glyph so a burst reads as one projectile repeated.
func _round(at: Vector2, k: float, ink: Color, dark: Color) -> void:
	var s := float(_s)
	var bw := 20.0 * k
	var bh := 11.0 * k
	_r(at + Vector2(-bw * 0.5, -bh * 0.5) * s, Vector2(bw, bh) * s, ink)
	_r(at + Vector2(bw * 0.5, -bh * 0.35) * s, Vector2(5.0 * k, bh * 0.7) * s, ink)
	_r(at + Vector2(bw * 0.5 + 5.0 * k, -1.5 * k) * s, Vector2(4.0 * k, 3.0 * k) * s,
		UITheme.HOT)
	_r(at + Vector2(-bw * 0.5 - 3.0 * k, -bh * 0.5) * s, Vector2(3.0 * k, bh) * s, dark)

## Motion behind a round. Every attack travels left to right, which is the one
## piece of grammar that makes the attack family read as a family.
func _tracer(at: Vector2, lines: int, dark: Color) -> void:
	var s := float(_s)
	for i in lines:
		_r(at + Vector2(-float(i) * 3.0, -4.0 + float(i) * 4.0) * s,
			Vector2(14.0 - float(i) * 3.0, 2) * s, dark)

func _r(p: Vector2, sz: Vector2, col: Color) -> void:
	draw_rect(Rect2(p, sz), col, true)

func _z(r: Rect2) -> Rect2:
	return Rect2(r.position * float(_s), r.size * float(_s))

func _plate(r: Rect2) -> void:
	draw_rect(r, UITheme.PANEL, true)

func _gem(r: Rect2, text: String, col: Color) -> void:
	draw_rect(r, UITheme.VOID, true)
	draw_rect(r, UITheme.LINE, false, 1.0 * float(_s))
	var f := UITheme.pixel_font()
	var fs := UITheme.FS_SMALL * _s
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, r.position + Vector2((r.size.x - tw) * 0.5, r.size.y * 0.5 + fs * 0.42),
		LowHull.scr(self, text, fs, f), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

## Always printed, even at zero: a cold build's chase stat must be visible. Vent runs backwards.
## Why: docs/why/CardView.md#heat-text
func _heat_text() -> String:
	if card.vent_all:
		return "-A"
	var n := card.net_heat()
	return str(n) if n >= 0 else "-%d" % absi(n)

func set_playable(can_play: bool) -> void:
	playable = can_play
	modulate.a = 1.0 if can_play else UITheme.DIM

## The hand sets it: `_ready` fires before position is set, so cards animated to the top.
## Why: docs/why/CardView.md#hover-lift
func set_base_y(y: float) -> void:
	_base_y = y

## Carried by the hand. Kills any lift in flight and refuses new ones until it
## is put down; see `_animate_lift`.
var held: bool = false

func set_held(on: bool) -> void:
	if held == on:
		return
	held = on
	if on:
		if _tween != null and _tween.is_running():
			_tween.kill()
		return
	# Put down: an armed card was refused its lift while carried, so it takes it now.
	if armed:
		_animate_lift(-22.0)


func _ready() -> void:
	_base_y = position.y
	mouse_entered.connect(_on_hover_in)
	mouse_exited.connect(_on_hover_out)
	gui_input.connect(_on_input)

## Click means something only when a card asks you to pick; click-to-play would choose targets.
## Why: docs/why/CardView.md#picking
var picking: bool = false

func set_picking(on: bool) -> void:
	if picking == on:
		return
	picking = on
	# Full brightness while picking: a hand greyed end to end reads as nothing can be done.
	modulate.a = 1.0 if (on or playable) else UITheme.DIM
	queue_redraw()

func _on_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	# The picking guard stays first: aiming one card while another waits resolves two in no order.
	if picking:
		accept_event()
		chosen.emit(self)
		return
	if not playable or not (get_parent() is HandView):
		return
	accept_event()
	# Picking up ends the hover: no mouse_exited fires, so the keyword panel covered the enemy.
	# Why: docs/why/CardView.md#grab-gesture
	hovered.emit(self, false)
	grabbed.emit(self, get_global_transform() * mb.position)

## Pointed at and playable, or armed: the card wears the one outline (C1). The lift stays;
## the warm tint it used to take is gone, the outline being the whole signal.
var marked: bool = false


func _set_marked(on: bool) -> void:
	if marked == on:
		queue_redraw()
		return
	marked = on
	queue_redraw()


func _on_hover_in() -> void:
	emitted_hover(true)
	if not playable:
		return
	_set_marked(true)
	_animate_lift(-8.0)

func _on_hover_out() -> void:
	emitted_hover(false)
	_set_marked(armed)
	_animate_lift(0.0)
	if lit_word != "":
		_on_word(lit_word, false)

## Only in a hand: elsewhere it slid cards to y=0 and stacked the gallery into its first row.
## Why: docs/why/CardView.md#hover-lift
func _animate_lift(offset: float) -> void:
	if not (get_parent() is HandView):
		return
	# A carried card owns its position, or the lift fights the hand's lerp and the card shakes.
	if held:
		return
	# An armed card owns its own height. Hovering off it mid-aim would otherwise
	# tween it back down into the fan while the line is still attached to it.
	if armed and not is_equal_approx(offset, -22.0):
		return
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:y", _base_y + offset, 0.12)

func emitted_hover(entered: bool) -> void:
	hovered.emit(self, entered)

## Armed borrows the hover lift and must win against hover, as the pointer leaves while aiming.
## Why: docs/why/CardView.md#armed-card
var armed: bool = false

func set_armed(on: bool) -> void:
	if armed == on:
		return
	armed = on
	_set_marked(on)
	_animate_lift(-22.0 if on else 0.0)


## No `_get_drag_data`: `set_drag_preview` pins the card to the pointer, but aiming needs it still.
## Why: docs/why/CardView.md#grab-gesture


## A card on top of the hand would swallow the drop, so it forwards: put it here.
func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.has("card")) or data["card"] == card:
		return false
	var hand := get_parent() as HandView
	if hand != null:
		# Hand-local x, so the slot is chosen by where the cursor is rather than
		# by which card is currently sliding underneath it.
		hand.preview_at(position.x + _pos.x, data["card"])
	return true

func _drop_data(_pos: Vector2, data: Variant) -> void:
	var hand := get_parent() as HandView
	if hand != null:
		hand.reorder_onto(data["card"], self)
