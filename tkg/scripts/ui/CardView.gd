class_name CardView
extends Control

## One card, at one of exactly two scales.
##
## The layout is a fixed zone map in HAND-SCALE pixels, multiplied by _s. Inspect
## is an exact 2x of hand, which is the whole reason the numbers below are the
## numbers below: card furniture is drawn once on a true pixel grid and doubles
## with no artifacts, while vector text re-renders at each scale and does not
## care. Any size between the two would put the frame on half-pixels.
##
## 96x130 is not a preference either. The native resolution is 640x360, a hand
## is five cards, and 5 x 96 + gaps fits across it. The previous 132 did not:
## five of those is 660px on a 640px screen, so the hand was already wider than
## the game before anything was drawn.
##
## CORNER GRAMMAR IS STRICT: one corner, one meaning. Energy top-left is what you
## pay; heat top-right is what playing it leaves behind. Anything that triggers
## on draw, in hand, or at end of turn lives in the TEXT BOX and never in a
## corner. The mirrored corners are the tutorial — every card silently teaches
## "this is the cost, this is the byproduct".

signal chosen(view: CardView)
signal hovered(view: CardView, entered: bool)

## Hand scale. Named CARD_W/CARD_H because the hand layout has always called
## them that.
## 112, and every pixel of the increase goes to the content column — the banner
## is unchanged at 13. Five cards at 112 plus gaps is 580 of a 640 screen, so
## the width that mattered when this was frozen at 96 still holds.
const CARD_W := 112
## 160, not 130. The art window was thirty pixels of a card whose whole selling
## point is a pixel-art module sprite; doubling it to sixty gives the picture
## room to be the reason you look at the card. The width is untouched, because
## width is the constrained axis — five cards at 96 is 480 of a 640 screen, and
## nothing about a taller card changes that. Height is the axis with slack.
const CARD_H := 160
const INSPECT_W := CARD_W * 2
const INSPECT_H := CARD_H * 2

## The zone map, in hand-scale pixels. Everything below multiplies by _s.
##
## The name sits directly under the cost gems and above the art. Reading order
## is then cost -> name -> picture, which is the order you actually use a hand
## in: what it costs decides whether you read on at all. It also puts the two
## things that survive at 96px — the number and the verb — in the top third,
## which is the only part of a card you can sequence a turn from.
## Thirteen wide, inset by one, and ODD on purpose.
##
## Odd is load-bearing: the marks must centre in it, so the leftover either side
## has to split evenly. An even width has no middle pixel at all, which is the
## half-pixel that made every emblem read off-centre when this started.
##
## Thirteen leaves a field of eleven inside the border, for a mark of nine — a
## pixel of house colour showing either side of its own emblem. Seventeen was
## about a fifth of the card given to one flat block of colour; eleven made the
## marks so narrow they had to stretch vertically to stay legible, which is its
## own kind of wrong. Nine across and nine tall is the size at which these
## shapes are square.
const Z_BANNER := Rect2(2, 1, 13, 158)      ## the house, full height, left edge
const Z_ENERGY := Rect2(16, 3, 13, 13)      ## what you pay
const Z_HEAT := Rect2(96, 3, 13, 13)        ## what it leaves behind
## Two lines. "Suppressing Fire" is sixteen characters and ran off the right
## edge of the card on one — and a verb pool full of two-word names means that
## is the common case, not the exception. Wrapping costs the art four pixels
## and buys every name in the game room to be itself.
const Z_NAME := Rect2(16, 18, 93, 22)       ## the verb
const Z_ART := Rect2(16, 42, 93, 60)        ## the granting module's sprite
## Eleven, not nine. An 8px font is not 8px tall once Godot adds its leading,
## so a nine-pixel zone let ATTACK render down into the first line of the text
## box and the two printed on top of each other. Zones have to be sized for
## what the font DOES, not for what its point size is called.
## Tucked under the art, left-aligned, like a caption on a plate.
##
## It was centred in the gutter between the picture and the rules, on the idea
## that it belonged to neither. It reads better belonging to the ART: the
## picture and the word under it are one statement — here is the thing, here is
## what kind of thing it is — and the effect text is a separate paragraph
## below. Centred and floating, it looked like a heading for the rules, which
## it is not.
##
## Placed from the INK, not from the box. Measured: Silkscreen at 8px is 11
## tall with an ascent of 9 and a descent of 2, so a line of caps paints rows 2
## through 9 of its box and leaves the bottom two empty. Every gap set by eye
## came out lopsided because of those two pixels. Art ends at 102, type ink lands at
## 108, text ink at 121 — six pixels of clearance either side, ink to ink.
const Z_TYPE := Rect2(16, 106, 93, 11)       ## type + lane
## The text box runs to the bottom of the card. There is no provenance footer:
## the module lives in the readout now, so the row it used to occupy goes to the
## thing that was actually short of space.
const Z_TEXT := Rect2(16, 119, 93, 39)

var card: CardData
var playable: bool = true

var _s: int = 1
var _tween: Tween
var _base_y: float = 0.0
var _tint: Color = UITheme.CHILL

func setup(c: CardData, can_play: bool, scale_step: int = 1) -> void:
	card = c
	playable = can_play
	_s = maxi(1, scale_step)
	_tint = DB.manufacturer_colour(c.manufacturer)
	custom_minimum_size = Vector2(CARD_W * _s, CARD_H * _s)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP

	Widgets.clear(self)

	# Name is on the card at BOTH scales. Effect text is not: it is unreadable
	# at 96px and pretending otherwise costs the room the art needs. Cards have
	# to be sortable from the top third alone; the text is confirmation you go
	# looking for, not discovery.
	# The NAME carries rarity.
	#
	# It is the one string on the card at both scales, so colouring it costs
	# nothing and reaches everywhere — and it puts "how good is this" on the
	# same glance as "what is it", which is the pair you sort a hand by.
	var nm := UITheme.body(c.name, ModuleData.rarity_ink(c.source_rarity),
		UITheme.FS_SMALL * _s)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.clip_text = true
	# Two 8px lines do not fit in two 8px worth of plate: Godot adds its own
	# line spacing on top, so "Suppressing Fire" wrapped correctly and then had
	# "Fire" clipped off the bottom. Tighten the leading and give the plate the
	# room the font actually asks for.
	nm.add_theme_constant_override("line_spacing", 0)
	# Centred in the plate rather than parked at its top. The plate is sized for
	# the WORST case — two lines — and most verbs are one, so anchoring to the
	# top left every short name floating above a band of empty plate. The zone
	# is fixed; what sits in it should be centred in it.
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(nm, Z_NAME, 2)
	var ty := UITheme.body(_type_line(), UITheme.COLD, UITheme.FS_SMALL * _s)
	ty.add_theme_constant_override("line_spacing", 0)
	_place(ty, Z_TYPE, 2)

	# Effect text at BOTH scales.
	#
	# card-design says "effect text is unreadable at hand scale, full stop" and
	# that turns out to be untrue for this game specifically: 8px Silkscreen is
	# the body font of the entire UI — the HUD, every panel, the name and type
	# line on this very card — so if it were unreadable at 96px the game would
	# already be unreadable everywhere. The rule was written for a card that
	# had no room; this zone map gave the text box the provenance row and it now
	# holds about sixty characters, which covers every card in the catalog.
	#
	# It also removes a real inconsistency: the text plate was being DRAWN at
	# both scales and filled at one, so a hand-scale card carried an empty
	# recessed panel where its rules should be.
	# Rich text, so the words that have rules behind them can say so.
	#
	# Underlined and lifted to ICE: two channels, because colour alone fails a
	# colourblind reader and an underline alone is easy to miss at 8px. It marks
	# exactly the terms this card's own keywords() can explain, so a word is
	# only ever underlined where there is something to look up.
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_font_override("normal_font", UITheme.pixel_font())
	body.add_theme_font_size_override("normal_font_size", UITheme.FS_SMALL * _s)
	body.add_theme_color_override("default_color", UITheme.CHILL)
	body.add_theme_constant_override("line_separation", 0)
	body.text = c.describe_rich()
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

## "Attack · Ballistics". The type is a structural fact and the lane is the
## verb-pool key — set-bonus play needs the lane scannable, so it prints even
## when the card is unbranded.
func _type_line() -> String:
	var lane := String(card.lane)
	if lane == "":
		return card.type_name().to_upper()
	return "%s · %s" % [card.type_name().to_upper(), lane.to_upper()]

## The full readout, as a native tooltip.
##
## OPT-IN: Godot only asks for a tooltip when tooltip_text is non-empty, and
## nothing sets that by default. The hand and the gallery build their own
## readouts with their own timing and placement — a second one appearing under
## the cursor would be two panels saying the same thing — so they leave it
## alone and get no tooltip. Anywhere a card is just sitting there being looked
## at, setting tooltip_text is enough.
##
## Same Widgets.card_readout() the other two use, so the three cannot drift.
func _make_custom_tooltip(_for_text: String) -> Object:
	if card == null:
		return null
	# Never in a hand, whatever anybody set on the card. The hand builds this
	# same panel itself, on its own delay and above the fan where it cannot
	# cover the board, and a native tooltip would be a second copy of it
	# floating at the cursor. The rule above says the hand opts out by leaving
	# tooltip_text empty; this is the rule enforced where it can be broken by
	# accident rather than only stated where it can be read.
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

	# The house banner. Brand is colour, emblem and cut; TYPE is structure. The
	# two channels never share an encoding, so a colourblind player reads type
	# off the silhouettes and the house off the mark, and both survive a 96px
	# thumbnail.
	if not dim:
		_banner()

	# The real cost, malfunction or not. card-design dashes the corner only on
	# the sub-states you cannot pay for — Inert and Active — and everything junk
	# in this game so far is Patchable: you can always buy the fight by purging
	# it. A dash on a card that has a price is the corner telling a lie.
	_gem(_z(Z_ENERGY), str(card.energy), UITheme.ICE)
	_gem(_z(Z_HEAT), _heat_text(), UITheme.EMBER if card.net_heat() >= 0 else UITheme.GOOD)

	# Art window. Recessed, one shade darker, so vector type over it stays legible.
	var art := _z(Z_ART)
	draw_rect(art, UITheme.VOID, true)
	draw_rect(art, UITheme.LINE, false, 1.0 * s)
	if dim:
		# Static hatch. Damage you can see from across the hand.
		var step := 3.0 * s
		var y := art.position.y
		while y < art.end.y:
			draw_line(Vector2(art.position.x, y), Vector2(art.end.x, y),
				Color(0.42, 0.38, 0.44, 0.5), s)
			y += step
	elif not _draw_art(art):
		_type_glyph()

	# Recessed plates at BOTH scales, including the ones that only hold text at
	# inspect. The furniture is one layout drawn once and doubled — that is the
	# whole reason the two sizes are an exact 2x — so hiding a plate at hand
	# scale does not save anything, it just leaves a hole where a panel should
	# be. An empty plate reads as a card with a quiet lower half; an empty
	# rectangle of background reads as a card that failed to finish drawing.
	_plate(_z(Z_NAME))
	_plate(_z(Z_TEXT))

	# Charge pips: banked turns are STATE, and state is the one thing you
	# sequence a whole turn around, so it gets structure rather than text.
	# Along the bottom edge of the art, where the eye already is.
	if card.charge_turns > 0:
		var px := (Z_ART.position.x + 2) * s
		var py := (Z_ART.end.y - 4) * s
		for i in card.charge_turns:
			draw_rect(Rect2(px + i * 6.0 * s, py, 4.0 * s, 2.0 * s), UITheme.FLARE, true)

	# No rarity swatch and no provenance row. Rarity is the colour of the name
	# (see setup) and the module is named in the readout beside the card, which
	# between them cost zero pixels and freed a whole row for effect text.
	#
	# The tradeoff worth knowing about: card-design calls the provenance footer
	# load-bearing under the verb model, because the name bar carries the VERB
	# and the footer was the only thing identifying the module — and mid-run
	# scrap decisions get made while looking at a hand. The rarity colour keeps
	# most of that answer on the card; the exact module now needs the readout.

## The manufacturer banner: a field, a mark, and a cut.
##
## A 2px accent stripe carried the house colour and nothing else — brand as a
## legal requirement rather than as identity. A banner is the emblem's largest
## habitat, and at 13px wide it still has room for the three things that
## distinguish a house at a glance: the ground it flies on, the mark it carries,
## and the shape of its own bottom edge.
##
## The cut is doing real work, not decoration. It is the one brand channel that
## survives with no colour at all — Korvan ends square because decoration is for
## people whose guns jam; Redline ends torn because salvage does not finish
## edges; Verity ends in a swallowtail because it can afford to.
func _banner() -> void:
	var s := float(_s)
	var man: ManufacturerData = DB.manufacturers.get(card.manufacturer)
	var b := _z(Z_BANNER)
	var field := man.field if man != null else UITheme.PANEL
	var mark := man.colour if man != null else UITheme.COLD
	draw_rect(b, field, true)
	_cut(b, mark)
	# Centred on the energy gem's row, not on the banner's own.
	#
	# Z_ENERGY runs y 3 to 16, so a centre of 9 puts the tallest marks — Solari's
	# rays, Calyx's cross — at exactly 3 to 16 as well. The house and the cost
	# then share one horizontal line across the top of the card, which is the
	# line the eye starts on.
	# Centre taken FROM the banner, not written next to it.
	#
	# It was a hardcoded 9 while the flag's real centre is 9.5 — measured, not
	# guessed — so every mark sat half a pixel left, which at 1x rounds to a
	# whole one. Two numbers that must agree should never be two numbers.
	#
	# Vertically it lines up with the energy gem rather than the flag: the house
	# and the cost then share the top line of the card, which is where the eye
	# starts.
	_emblem(Vector2(b.position.x + b.size.x * 0.5,
		(Z_ENERGY.position.y + Z_ENERGY.size.y * 0.5) * s), mark, field)
	# EVERY banner is outlined, and the outline goes on LAST.
	#
	# It started as a light-field rule — Verity and Calyx bleed into the card
	# without one. But two houses fly fields that are the card's own colour:
	# Redline's charcoal is #1c2127 against a #161f2c panel, and Cygnet's
	# #16202e is nearer still. Those banners had no edge at all, so their hems
	# were carving shapes out of a flag whose outline you could not see, and the
	# bottom of the flag simply merged into the card.
	#
	# In the house's own mark, dimmed: it reads on a dark field and stays quiet
	# on a bright one. Last, because a frame drawn before its contents is not a
	# frame — underneath the hem it lost exactly the edge this is for.
	# Four filled rects, not draw_rect's outline mode.
	#
	# An unfilled draw_rect strokes the boundary rather than the pixels inside
	# it, so at 1px the stroke straddles the edge and rounds inward on one side
	# and outward on the other. That is a one-pixel asymmetry applied to the
	# frame every emblem is judged against — measured, the mark sat dead centre
	# and still read a pixel right, because the border had quietly eaten the
	# right margin and not the left. Explicit rects land where they are told.
	var edge := mark.darkened(0.3)
	draw_rect(Rect2(b.position.x, b.position.y, s, b.size.y), edge, true)
	draw_rect(Rect2(b.end.x - s, b.position.y, s, b.size.y), edge, true)
	draw_rect(Rect2(b.position.x, b.position.y, b.size.x, s), edge, true)
	draw_rect(Rect2(b.position.x, b.end.y - s, b.size.x, s), edge, true)

## Carve the bottom edge into the house's shape by painting the card back over
## it. Cheaper than authoring seven polygons and it stays on the pixel grid.
func _cut(b: Rect2, mark: Color) -> void:
	draw_cut(self, card.manufacturer, b, mark, UITheme.PANEL2, float(_s))

## The seven hems, drawn onto any canvas at any scale.
##
## Static and free of the card for the same reason draw_emblem is: the chassis
## select flies these banners too, at four times the size. The offsets are
## hand-authored — a hem is the one part of this card designed by eye rather
## than derived — so a second copy would be a second set of numbers to get
## wrong.
##
## `back` is whatever the banner is sitting ON. Most of these shapes are CUT,
## by painting the background back over the flag, so passing the wrong colour
## does not misdraw the hem — it makes the hem invisible.
static func draw_cut(ci: CanvasItem, man: StringName, b: Rect2, mark: Color,
		back: Color, s: float) -> void:
	var base := b.end.y

	# Everything below draws through this, and it will not paint outside the
	# flag. A shape that escapes its own banner reads as a rendering fault
	# rather than as a design. Clipping makes "inside the banner" a property of
	# the function instead of arithmetic somebody checked once.
	var hem := func(r: Rect2, col: Color) -> void:
		var x0 := maxf(r.position.x, b.position.x)
		var y0 := maxf(r.position.y, b.position.y)
		var x1 := minf(r.end.x, b.end.x)
		var y1 := minf(r.end.y, b.end.y)
		if x1 > x0 and y1 > y0:
			ci.draw_rect(Rect2(x0, y0, x1 - x0, y1 - y0), col, true)
	match man:
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
			# A hairline seam. Two bands with one dark line between them: a join
			# you are not supposed to notice, executed so well it becomes the
			# decoration.
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
			# A torn hem, DRAWN rather than carved. Every other house cuts its
			# shape by painting the card back over the flag, which relies on the
			# field differing from the card — and Redline's #1c2127 against a
			# #161f2c panel IS the card. A subtraction needs two colours to
			# subtract between, so this one goes on as a positive.
			hem.call(Rect2(b.position.x, base - 3 * s, b.size.x, 3.0 * s), mark)
			for i in 6:
				var hh: float = [11, 4, 16, 7, 13, 5][i]
				hem.call(Rect2(b.position.x + i * 2 * s, base - hh * s,
					2.0 * s, hh * s), mark)
		&"korvan":
			# Flat, with a riveted steel band. Decoration is for people whose
			# guns jam.
			hem.call(Rect2(b.position.x, base - 4 * s, b.size.x, 3.0 * s),
				mark.darkened(0.45))
			for i in 4:
				hem.call(Rect2(b.position.x + (3 + i * 2) * s, base - 3 * s, s, s), mark)
		_:
			# Unbranded: nothing. Precursor tech and grown things have no house
			# to fly for, and a blank hem says that better than any shape would.
			pass

## `c` is the flag's true centre, and every offset below is measured from it as
## a HALF — -6.5 with a width of 13, not -6 with a width of 13. That is what
## straddling a centre actually looks like: an odd-width mark has to start half
## its width to the left, and half of 13 is 6.5. Writing whole numbers there put
## every emblem half a pixel off, in the same direction, on all seven houses.
func _emblem(c: Vector2, mark: Color, field: Color) -> void:
	draw_emblem(self, card.manufacturer, c, float(_s), mark, field)

## The seven marks, drawn onto any canvas at any scale.
##
## Static and free of the card because the ship tab flies these too: a hull is
## built by a manufacturer now, and its header wears the same emblem as the
## cards that manufacturer grants. Two copies of these offsets would be two
## copies to fix the next time one is half a pixel out — which has already
## happened once, to all seven at the same time.
static func draw_emblem(ci: CanvasItem, man: StringName, c: Vector2, s: float,
		mark: Color, field: Color) -> void:
	var r := func(off: Vector2, sz: Vector2, col: Color) -> void:
		ci.draw_rect(Rect2(c + off * s, sz * s), col, true)
	match man:
		&"korvan":
			# Three descending armour slabs. Armour as heraldry.
			# Pitch 4: two of bar, two of gap, three times over. The bars were
			# at -4.5, -1 and 2.5, which put 1.5 pixels between them — and half
			# a pixel of gap does not exist, so one rendered as 1 and the other
			# as 2. Whole numbers or the spacing is decided by the rasteriser.
			r.call(Vector2(-4.5, -5), Vector2(9, 2), mark)
			r.call(Vector2(-3.5, -1), Vector2(7, 2), mark)
			r.call(Vector2(-2.5, 3), Vector2(5, 2), mark)
		&"solari":
			# Sun disc, four cardinal rays.
			r.call(Vector2(-1.5, -1.5), Vector2(3, 3), mark)
			r.call(Vector2(-0.5, -4.5), Vector2(1, 3), mark)
			r.call(Vector2(-0.5, 1.5), Vector2(1, 3), mark)
			r.call(Vector2(-4.5, -0.5), Vector2(3, 1), mark)
			r.call(Vector2(1.5, -0.5), Vector2(3, 1), mark)
		&"probate":
			# A bucket narrowing to its teeth. The bite is the brand.
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

## THE CARD'S OWN ILLUSTRATION, if one exists. False means there is none and the
## drawn glyph should take the window instead.
##
## AT WHOLE MULTIPLES ONLY. The illustration is authored at the window's own
## size, so hand scale draws it 1:1 and inspect draws it at exactly 2 — the same
## reason the two card sizes are an exact 2x and not a comfortable 1.8. Anything
## else resamples pixel art onto a grid it was not drawn for, which is the one
## thing the art direction refuses outright.
##
## Centred rather than stretched when the file is not the size it should be. A
## wrong-sized asset is a mistake to SEE, and `-- artcheck` names it; silently
## scaling it to fit would hide exactly the mistake that check exists to catch.
func _draw_art(where: Rect2) -> bool:
	var tex: Texture2D = DB.card_art(card.art_key())
	if tex == null:
		return false
	var at := where.position + (where.size - Vector2(tex.get_size()) * float(_s)) * 0.5
	draw_texture_rect(tex, Rect2(at.round(), Vector2(tex.get_size()) * float(_s)), false)
	return true

## What the module looks like, until there is a module sprite to show.
##
## The art window is the largest thing on the card and every module currently
## ships without a sprite, so it would otherwise be the largest thing on the
## card showing nothing. The doc requires a card be sortable from its top third
## alone, and a black rectangle sorts nothing.
##
## Shape rather than colour, because colour is the manufacturer channel and the
## two must never share an encoding — these silhouettes work identically for a
## colourblind player. Drawn from rects on the pixel grid so they double cleanly
## into inspect.
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
			# THE SAME ROUND, SEVERAL TIMES, and this is the split that does the
			# most work in the whole set: "Deal 2 x 5" is a stream and "Deal 40"
			# is a hammer, and until now they were one picture.
			#
			# Drawn to the ACTUAL hit count up to four, then smaller, so a player
			# can count them off a 96px thumbnail. Past four it stops counting and
			# starts meaning "a lot", which is the honest reading of Deal 2 x 5
			# anyway — nobody counts five rounds, they see a stream.
			var n := clampi(card.hits, 2, 4)
			var k := 1.0 - 0.16 * float(n - 2)
			for i in n:
				var x := -30.0 + float(i) * (26.0 - float(n) * 2.0)
				_round(c + Vector2(x, 0) * s, k * 0.72, ink, dark)
		&"pyre":
			# An attack whose number IS your heat. A round with the reactor
			# showing through it — the only attack glyph that is lit from inside,
			# because it is the only one whose damage comes out of the ship.
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
			# A screen that falls down at the end of the turn. Same footprint as
			# Brace and deliberately SEGMENTED — gaps say temporary before a word
			# is read, and the two are the most important pair on the card to be
			# able to tell apart at a glance.
			for i in 3:
				_r(c + Vector2(-13, -20 + i * 14) * s, Vector2(26, 10) * s,
					ink if i == 1 else dark)
		&"feedback":
			# A wall that shoots back, drawn as a wall and THE ATTACK GLYPH'S OWN
			# ROUND leaving it. Reusing the round rather than inventing a spark is
			# the whole point: feedback is defence that deals damage, and the
			# picture should be made of the two things it is made of.
			#
			# Leaving to the RIGHT, with the rest of the attack family, because
			# right is where this card's damage goes.
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
			# A reticle closing on something. The only glyph that is about the
			# NEXT card rather than this one.
			# Written out, not looped. An L has a handedness and there are four
			# of them — see ModuleIcon._glyph, where the derived version read as
			# four unrelated ticks.
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
			# BROKEN, and it used to draw a vent — a Dross card was showing the
			# picture for "throw heat off", which is the single most misleading
			# thing the old set did. Scattered, off-grid, going nowhere.
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

## One round: a body and a nose, pointed right, at a fraction of full size.
##
## Shared by every attack glyph so that a burst is visibly the SAME projectile
## repeated rather than a different drawing that happens to mean attack.
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
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

## ALWAYS printed, even at zero.
##
## A zero-heat attack is a chase property — the whole point of a cold build is
## that it can keep swinging — and a stat you cannot see is a stat you cannot
## chase. Vent cards print the same number running backwards, which teaches that
## heat is bidirectional using the corner that already exists rather than a new
## one.
func _heat_text() -> String:
	if card.vent_all:
		return "-A"
	var n := card.net_heat()
	return str(n) if n >= 0 else "-%d" % absi(n)

func set_playable(can_play: bool) -> void:
	playable = can_play
	modulate.a = 1.0 if can_play else 0.34

func _ready() -> void:
	_base_y = position.y
	mouse_entered.connect(_on_hover_in)
	mouse_exited.connect(_on_hover_out)
	gui_input.connect(_on_input)

## PICKING, not playing. A card is played by dragging it onto a target — your
## hull for defence and utility, an enemy for anything that hits — and
## click-to-play would quietly choose a target for you, which is the decision the
## drag exists to make.
##
## A click means something only while a card has asked you to pick some of your
## hand. There is no target to guess at then: the question is which card, and
## pointing at it is the whole answer.
var picking: bool = false

func set_picking(on: bool) -> void:
	if picking == on:
		return
	picking = on
	# Full brightness while picking, whatever `playable` said. Nothing in the
	# hand is playable mid-choice, and a hand greyed out end to end reads as
	# "you cannot do anything" at the exact moment you must.
	modulate.a = 1.0 if (on or playable) else 0.34
	queue_redraw()

func _on_input(event: InputEvent) -> void:
	if not picking:
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	chosen.emit(self)

func _on_hover_in() -> void:
	emitted_hover(true)
	if not playable:
		return
	_tint = UITheme.FLARE
	queue_redraw()
	_animate_lift(-8.0)

func _on_hover_out() -> void:
	emitted_hover(false)
	_tint = DB.manufacturer_colour(card.manufacturer)
	queue_redraw()
	_animate_lift(0.0)

## Only in a hand.
##
## The lift is a claim about PLAYABILITY — "this one, now" — which is a fact
## about a hand and meaningless in a catalog. It also cannot work anywhere else:
## it animates position.y back to a rest value captured at _ready(), before any
## container has laid the card out, so inside a flow container every hovered
## card slid up to y=0 and the gallery stacked itself into its own first row.
##
## Gated on the parent rather than on a flag the caller has to remember, because
## the rule is not "the gallery is special" — it is "position is the hand's to
## own, and nothing else may fight its container for it".
func _animate_lift(offset: float) -> void:
	if not (get_parent() is HandView):
		return
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:y", _base_y + offset, 0.12)

## Fly the card toward the enemy as it resolves, then fade.
func play_flourish(target: Vector2) -> void:
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "global_position", target, 0.18)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_property(self, "scale", Vector2(0.7, 0.7), 0.18)
	tw.chain().tween_callback(queue_free)

func emitted_hover(entered: bool) -> void:
	hovered.emit(self, entered)

## Dragging a card onto an enemy targets it. The preview is a copy so the cursor
## still shows what is being thrown.
func _get_drag_data(_pos: Vector2) -> Variant:
	# Same rule: you can drag a card out of a hand and nowhere else. And not at
	# all while a choice is open — dragging one card onto an enemy while another
	# is waiting to be picked resolves two cards in an order neither stated.
	if picking:
		return null
	if not playable or not (get_parent() is HandView):
		return null
	# Picking it up ends the hover. Godot does not send mouse_exited when a drag
	# begins — the cursor never technically leaves — so without this the keyword
	# panel stays open over the board for the whole drag, covering the enemy you
	# are trying to aim at.
	hovered.emit(self, false)
	var ghost := CardView.new()
	ghost.setup(card, true, _s)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wrap := Control.new()
	wrap.add_child(ghost)
	ghost.position = -Vector2(CARD_W * _s, CARD_H * _s) * 0.5
	set_drag_preview(wrap)
	# Hide the original outright rather than ghosting it. A half-faded copy reads
	# as a rendering fault; an empty slot reads as "you are holding that one".
	# Alpha rather than visible so the hand does not reflow mid-drag.
	modulate = Color(1, 1, 1, 0)
	# And stop it intercepting. The reorder preview parks this card under the
	# cursor by design, so leaving it clickable means the drop lands on the card
	# being dragged, gets refused, and snaps back.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	return {"card": card, "view": self}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate = Color.WHITE
		mouse_filter = Control.MOUSE_FILTER_STOP

## A card sits on top of the hand and would otherwise swallow the drop, so it
## forwards: releasing over a card means "put it here", which is the whole point
## of dropping on that card rather than beside it.
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
