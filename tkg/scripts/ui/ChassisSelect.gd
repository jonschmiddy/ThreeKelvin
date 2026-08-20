class_name ChassisSelect
extends Control

## Which ship you fly out in: a manufacturer, then a weight class.
##
## The first screen of a run, and the first time the game asks you for anything.
## It exists because hulls now have makers: a chassis sets four of your six
## attributes, decides which cards your starting modules grant, and counts as
## one toward its own set bonus.
##
## TWO AXES, and they are genuinely different questions. The manufacturer is
## who you are — which cards, which set bonus, which attribute signature. The
## weight class is how much ship — hull, hardpoints, hand size, evasion. Every
## maker builds all three, so picking Redline does not force you into a paper
## hull; it means a Redline heavy is still the fastest heavy in the game.
##
## Selecting REALLY REFITS THE SHIP rather than previewing it — Run.fit_chassis()
## runs on every click — so the attribute block is reading the live ship, not a
## parallel calculation of what the ship would be. There is no second
## implementation to drift.

signal launched

const WEIGHTS := [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]
## The one ship on the screen, and the only one drawn at all.
##
## Doubled, and cropped to roughly the band the hull occupies. The sprite canvas
## is 240x120 with the ship about forty rows tall in the middle of it, so at 2x
## a 132-row window holds the whole hull and throws away the empty space above
## and below rather than the ship.
const HERO_SCALE := 2
const HERO_H := 132
## The gap between the banner and the identity column, reused as the indent for
## everything below that has to line up with it.
const HEAD_GAP := 12
## The identity header's height, held equal across all seven. Measured, not
## chosen: 169 is what the tallest of them needs today. See _build_detail.
const HEAD_H := 169
## The right-hand column, shared by the attribute block above and the loadout
## below so the two line up.
const SIDE_W := 300
## How far the rows in the chassis list are inset inside their buttons, so a
## selected row's fill has a margin before its text. The list's heading uses it
## too, or the two do not share a left edge.
const ROW_INSET := 5

var _sel: int = 0
var _weight: HullData.Weight = HullData.Weight.MEDIUM
var _list: VBoxContainer
var _detail: VBoxContainer
var _rows: Array[Button] = []

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_select(0)


func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 5)
	add_child(root)

	# Title left, LAUNCH right, on one line above everything.
	#
	# It used to be a full-width bar under the detail panel, which gave the least
	# interesting control on the screen the most weight — and put it below a
	# scroll, so the answer to "how do I start" depended on where you had
	# scrolled to. Up here it is always visible, always in the same place, and
	# small enough to read as the end of the process rather than the point of it.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(UITheme.header("CHOOSE A CHASSIS"))
	var tgap := Control.new()
	tgap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tgap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(tgap)
	var go := Widgets.button("LAUNCH", func() -> void: launched.emit())
	go.custom_minimum_size = Vector2(96, 0)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(go)
	root.add_child(top)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 5)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	# --- left: who built it. Narrow, because seven short words need no more.
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.custom_minimum_size = Vector2(126, 0)
	for i in DB.STARTABLE.size():
		var r := _maker_row(i)
		_rows.append(r)
		_list.add_child(r)
	split.add_child(Widgets.panel_with(_list))

	# --- right: how much of it
	#
	# Scrolled. Measured, the detail needs about 457px against 445 available —
	# and that was KORVAN, which does not have the longest backstory. Trimming
	# twelve pixels would fit one manufacturer and cut off another, so the height
	# is not something this screen gets to assume.
	#
	# LAUNCH is not in here for the same reason: it lives in the title row above,
	# where it cannot be scrolled away from.
	var col2 := VBoxContainer.new()
	col2.add_theme_constant_override("separation", 4)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 5)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_detail)
	col2.add_child(scroll)

	var wrap := Widgets.panel_with(col2)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(wrap)

## One manufacturer. Emblem and name only — the hull's name belongs beside the
## hull it names, and there are three of those now, so printing one here would
## have been printing whichever weight happened to be selected.
func _maker_row(i: int) -> Button:
	var man: StringName = DB.STARTABLE[i]
	var m: ManufacturerData = DB.manufacturers[man]

	# Widgets.button, not Button.new(). That is where every click and hover sound
	# in the game is wired, so building the Button directly made the chassis
	# select the one screen in the interface that answered silently.
	var btn := Widgets.button("", _select.bind(i))
	btn.flat = true
	btn.custom_minimum_size = Vector2(0, 34)
	btn.tooltip_text = "%s\n%s" % [m.name, m.identity]
	# Hover fills with the maker's SECONDARY colour — the field the emblem is
	# stamped on, not the accent. Seven rows that highlight identically make you
	# read the label to know what you are pointing at; seven that light up in
	# their own livery do not.
	btn.add_theme_stylebox_override("normal", UITheme.flat(UITheme.PANEL, UITheme.LINE, 0, 0, 4))
	btn.add_theme_stylebox_override("hover", UITheme.flat(m.field, m.colour, 0, 0, 4))
	btn.add_theme_stylebox_override("pressed", UITheme.flat(m.field, m.colour, 0, 0, 4))
	btn.add_theme_stylebox_override("focus", UITheme.empty())
	# The stylebox alone was not enough and could not have been: unselected rows
	# sit at DIM opacity, and Redline's field is #1c2127 against a #111823 panel
	# — a highlight worth two per cent of brightness, then dimmed by half. The
	# opacity is what actually reads, so hovering restores it.
	btn.mouse_entered.connect(func() -> void: _hover(i, true))
	btn.mouse_exited.connect(func() -> void: _hover(i, false))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 5
	row.offset_right = -5

	var badge := Badge.new()
	badge.man = man
	badge.mark = m.colour
	badge.field = m.field
	badge.scale_px = 2.0
	row.add_child(badge)

	var label := UITheme.body(DB.short_name(m.name).to_upper(), m.colour, UITheme.FS_HEAD)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)

	btn.add_child(row)
	return btn

## An unpicked manufacturer, and a picked one.
##
## Alpha alone was not enough of a difference. modulate multiplies, so pulling
## the colour channels down as well takes the saturation out of the emblem and
## the name — a dimmed Redline was still unmistakably red, which made seven rows
## of livery compete with the one you had actually chosen. Cooled and darkened,
## they read as a list; the selected one reads as the subject.
const DIM := Color(0.62, 0.66, 0.74, 0.42)
const LIT := Color(1, 1, 1, 1)

func _select(i: int) -> void:
	# Or it hangs over the new ship showing the last one's cards. The popup is a
	# child of this screen, not of the detail panel, so rebuilding the detail
	# does not take it with it.
	_close_deck()
	_sel = i
	_refit()
	for j in _rows.size():
		_rows[j].modulate = LIT if j == i else DIM
	_build_detail()

func _hover(i: int, on: bool) -> void:
	if i == _sel or i >= _rows.size():
		return
	_rows[i].modulate = LIT if on else DIM

func _pick_weight(w: HullData.Weight) -> void:
	_weight = w
	_refit()
	_build_detail()

func _refit() -> void:
	Run.fit_chassis(DB.STARTABLE[_sel], _weight)

func _build_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var man: StringName = DB.STARTABLE[_sel]
	var m: ManufacturerData = DB.manufacturers[man]

	# --- who built it. The banner the cards fly, four times the size.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", HEAD_GAP)

	var flag := Banner.new()
	flag.man = man
	flag.mark = m.colour
	flag.field = m.field
	head.add_child(flag)

	var idc := VBoxContainer.new()
	idc.add_theme_constant_override("separation", 2)
	idc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	idc.add_child(UITheme.body(m.name.to_upper(), m.colour, UITheme.FS_HEAD))
	idc.add_child(UITheme.body('"%s"' % m.tagline, UITheme.QUOTE, UITheme.FS_SMALL))
	idc.add_child(_gap(3))
	var lore := UITheme.body(m.backstory, UITheme.CHILL, UITheme.FS_SMALL)
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	idc.add_child(lore)
	idc.add_child(_gap(3))
	var ident := UITheme.body(m.identity, UITheme.COLD, UITheme.FS_SMALL)
	ident.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	idc.add_child(ident)
	idc.add_child(_gap(4))
	# The set bonuses are the strategy this maker is FOR, so they belong beside
	# its name rather than buried under the loadout — you are picking a way to
	# play, and these two lines are what it turns into. Given a heading because
	# unlabelled they read as trivia; they are the abilities.
	idc.add_child(UITheme.body("MANUFACTURER ABILITIES", UITheme.COLD, UITheme.FS_SMALL))
	# The hull perk belongs here on THIS screen. Every chassis a yard builds
	# carries the same authored perk — all three Korvan frames vent baffled — so
	# at the point of choosing a manufacturer it is one of their abilities, and
	# it is the only one you get without collecting anything.
	#
	# It is a HULL property, not a maker property, and the two come apart later:
	# LootGen rerolls the perk on a wreck, so a salvaged Korvan frame can carry
	# anything. That is why the tag reads HULL rather than 1+.
	var have := Run.manufacturer_count(man)
	var perk: Dictionary = DB.hull_perks.get(Run.hull.perk_id, {})
	var short := DB.short_name(m.name).to_upper()
	if not perk.is_empty():
		idc.add_child(_bonus("BUILT IN", str(perk.name), str(perk.text), m.colour, true))
	idc.add_child(_bonus("3+ %s" % short, m.set3_name, m.set3_text, m.colour, have >= 3))
	idc.add_child(_bonus("5+ %s" % short, m.set5_name, m.set5_text, m.colour, have >= 5))
	# What the two rows above are actually counting, and where this ship starts
	# on that count. The old wording explained the arithmetic — "modules from
	# this yard, plus the hull" — which is the rule, not the situation. You want
	# to know how close you are.
	# No running count here. The rows above already say what each ability needs,
	# and at the point of choosing a chassis the count is always two — a line
	# reporting it says nothing that changes between manufacturers. It belongs
	# on the ship screen, where it moves as you fit things.
	head.add_child(idc)
	# One height for every manufacturer. MEASURED: the identity column comes out
	# at 155 for four of the seven and 169 for the other three, the difference
	# being a single wrapped line of backstory. Left free, clicking down the list
	# shifted the ship, the attributes and the yard list up and down by fourteen
	# pixels — the page twitching while you compare things is the opposite of
	# what a comparison screen is for.
	#
	# A minimum rather than a fixed size, so prose that grows past this still
	# gets its line: it pushes into the scroll instead of being clipped.
	head.custom_minimum_size.y = HEAD_H
	_detail.add_child(head)

	_detail.add_child(UITheme.hsep())

	# --- what you are flying, and what it comes to on the six axes.
	#
	# Indented to clear the banner, so the hull's name starts on the same column
	# as the manufacturer's above it. Two names at two different left edges read
	# as two unrelated panels rather than as a heading and its subject.
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 14)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Name and class above, ship below. This is the only place the ship is drawn
	# now — the picker under it is a list, because two pictures of one hull was
	# the same information twice and the second one was smaller.
	var shipcol := VBoxContainer.new()
	shipcol.add_theme_constant_override("separation", 1)
	shipcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shipcol.add_child(UITheme.body(Run.hull.name.to_upper(), UITheme.ICE, UITheme.FS_HEAD))
	shipcol.add_child(UITheme.body(
		"%s CHASSIS · %s TIER" % [
			HullData.weight_name(Run.hull.weight).to_upper(), Run.hull.tier_letter()],
		UITheme.COLD, UITheme.FS_SMALL))
	var chosen := ShipView.new()
	chosen.setup_preview(Run.hull, HERO_H, HERO_SCALE)
	# The ship asks for NO width and takes what is left.
	#
	# At 2x the sprite is 480 wide, and 480 plus the 300 column plus the banner
	# indent came to more than the panel has. That does not clip — the detail
	# lives in a ScrollContainer, so the container simply sized itself to the
	# content, and every wrapping Label above then wrapped at that oversized
	# width and ran off the visible edge. The manufacturer backstory losing its
	# last word was this, not a text problem.
	#
	# Expanding instead of demanding means the arithmetic cannot go wrong again
	# at some other panel size: the hull is centred in whatever remains and
	# clipped by its own clip_contents, which is already how the height works.
	chosen.custom_minimum_size.x = 0
	chosen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shipcol.add_child(chosen)
	mid.add_child(shipcol)

	# Fixed width, and the same width the kit column below uses. Both sit at the
	# right of an HBox whose other child expands, so equal widths put ATTRIBUTES,
	# HARDPOINTS and YOU LAUNCH WITH on one column — they were three headings at
	# three different left edges before.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 3)
	right.custom_minimum_size = Vector2(SIDE_W, 0)
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(UITheme.body("ATTRIBUTES", UITheme.COLD, UITheme.FS_SMALL))
	var block := AttrBlock.new()
	block.setup(Run.attributes(), m.colour)
	right.add_child(block)

	# Hardpoints, in the same cells the refit screen uses. Slot pressure is the
	# whole install-or-scrap decision later, so it should be countable here —
	# before you commit — rather than discovered on the first drop.
	right.add_child(_gap(3))
	right.add_child(UITheme.body("HARDPOINTS", UITheme.COLD, UITheme.FS_SMALL))
	for s in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]:
		right.add_child(_mount_row(s))
	# Hand size sits with the hardpoints because it is the same kind of fact:
	# how much ship you get to use at once. It is not an attribute — nothing
	# checks against it — so it has no business in the block above.
	var hand := HBoxContainer.new()
	hand.add_theme_constant_override("separation", 6)
	var hl := UITheme.body("HAND", UITheme.COLD, UITheme.FS_SMALL)
	hl.custom_minimum_size = Vector2(46, 0)
	hand.add_child(hl)
	hand.add_child(UITheme.body("%d cards a turn" % Run.hand_size(),
		UITheme.CHILL, UITheme.FS_SMALL))
	right.add_child(hand)

	mid.add_child(right)
	_detail.add_child(_align(mid))

	# --- the three it builds, and what this one launches carrying. Side by side
	# because both are short lists and the panel is wide — stacked, they were
	# what pushed LAUNCH off the bottom of the screen.
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)

	var yard := VBoxContainer.new()
	yard.add_theme_constant_override("separation", 1)
	yard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Indented to match the rows under it. Those sit inside buttons that inset
	# their contents by ROW_INSET so the selected row's fill does not run right
	# up against its text — which left the heading alone at the true left edge,
	# five pixels adrift of the list it names.
	var yard_head := MarginContainer.new()
	yard_head.add_theme_constant_override("margin_left", ROW_INSET)
	yard_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	yard_head.add_child(UITheme.body("AVAILABLE CHASSIS", UITheme.COLD, UITheme.FS_SMALL))
	yard.add_child(yard_head)
	for w in WEIGHTS:
		yard.add_child(_weight_row(man, w, m))
	foot.add_child(yard)

	var kit := VBoxContainer.new()
	kit.add_theme_constant_override("separation", 1)
	kit.custom_minimum_size = Vector2(SIDE_W, 0)
	kit.size_flags_horizontal = Control.SIZE_SHRINK_END
	var kit_head := HBoxContainer.new()
	kit_head.add_theme_constant_override("separation", 8)
	kit_head.add_child(UITheme.body("STARTING MODULES", UITheme.COLD, UITheme.FS_SMALL))
	# The modules are the fiction; the DECK is what you actually play. Nine cards
	# is small enough to read in one look and is the only thing on this screen
	# that answers "what will my turns feel like" — which is the question a
	# chassis is really being chosen on.
	var deck_btn := Widgets.button("SEE DECK (%d)" % Run.deck_size(), _show_deck)
	deck_btn.add_theme_font_size_override("font_size", UITheme.FS_SMALL)
	kit_head.add_child(deck_btn)
	kit.add_child(kit_head)
	for mod in Run.installed:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 5)
		var st := UITheme.body(
			ModuleData.slot_name(mod.slot).to_upper(), UITheme.COLD, UITheme.FS_SMALL)
		st.custom_minimum_size = Vector2(46, 0)
		line.add_child(st)
		# Named in its rarity's colour, the same ladder the cards use. Almost
		# everything you launch with is Common steel; the one branded weapon is
		# the odd colour in the list, which is exactly what it is.
		line.add_child(UITheme.body(mod.name,
			ModuleData.rarity_colour(mod.rarity), UITheme.FS_SMALL))
		kit.add_child(line)
	foot.add_child(kit)
	_detail.add_child(_align(foot))


## Indent to the manufacturer-name column: past the banner and the gap after it.
## Derived from the banner rather than typed, so widening the flag moves
## everything that lines up with it.
func _align(c: Control) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(Banner.UNITS_W * Banner.S) + HEAD_GAP)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(c)
	return m

## One hardpoint row: what it is, how many are filled, how many exist.
func _mount_row(slot: ModuleData.Slot) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var label := UITheme.body(
		ModuleData.slot_name(slot).to_upper(), UITheme.COLD, UITheme.FS_SMALL)
	label.custom_minimum_size = Vector2(46, 0)
	row.add_child(label)
	var used := Run.slots_used(slot)
	var total := Run.slots_for(slot)
	var pads := ShipScreen.SlotPads.new()
	pads.setup(used, total)
	row.add_child(pads)
	row.add_child(UITheme.body("%d/%d" % [used, total], UITheme.CHILL, UITheme.FS_SMALL))
	return row

## Every card this chassis would deal you, laid out over the screen.
##
## Built from Run.installed rather than from a table of what the kit ought to
## grant, so it cannot disagree with the deck you actually launch with — the
## grant count is a rule with three inputs (slot, manufacturer, affixes) and a
## second implementation of it here would be a second place to get it wrong.
func _show_deck() -> void:
	if _deck_pop != null:
		return
	# Dimmed behind, but the popup itself is only as big as the cards need. A
	# full-screen sheet for ten cards reads as leaving the screen you were on;
	# this is meant to be a glance you take mid-comparison and dismiss.
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	# Anywhere outside the panel dismisses it. The panel sits on top and stops
	# the press, so this only ever fires on the dimmed margin.
	shade.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_close_deck())
	add_child(shade)
	_deck_pop = shade

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(centre)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UITheme.body("OPENING DECK", UITheme.ICE, UITheme.FS_HEAD))
	head.add_child(UITheme.body("%d cards · %d dealt a turn" % [
		Run.deck_size(), Run.hand_size()], UITheme.COLD, UITheme.FS_SMALL))
	var hgap := Control.new()
	hgap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hgap)
	head.add_child(Widgets.button("CLOSE", _close_deck))
	col.add_child(head)

	# Five across. A card is 112 wide, so this is the width that wraps ten cards
	# into two clean rows rather than leaving one stranded on a third.
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 5)
	flow.add_theme_constant_override("v_separation", 5)
	flow.custom_minimum_size = Vector2(CardView.CARD_W * 5 + 5 * 4, 0)
	for mod in Run.installed:
		for c in mod.resolved_cards():
			var v := CardView.new()
			v.setup(c, true, 1)
			# STOP so it can be hovered, and a non-empty tooltip_text so Godot
			# asks CardView for one — which hands back the same readout the hand
			# and the gallery show. Nine cards you cannot read the small print of
			# are nine pictures.
			v.mouse_filter = Control.MOUSE_FILTER_STOP
			v.tooltip_text = c.name
			flow.add_child(v)
	# Capped at two rows of cards. A deck that outgrows it scrolls rather than
	# pushing the panel off the top and bottom of the screen.
	col.add_child(Widgets.scroller(flow, CardView.CARD_H * 2 + 5))

	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	pad.add_child(col)
	centre.add_child(Widgets.panel_with(pad))

func _close_deck() -> void:
	if _deck_pop == null:
		return
	_deck_pop.queue_free()
	_deck_pop = null

var _deck_pop: Control = null

func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## One ability: what it costs, what it is called, what it does.
##
## The condition goes in the first column and says it in full — "3+ KORVAN" —
## rather than a bare "3+" that leaves you to work out three of what. The hull
## perk shares that column with "BUILT IN" — the other two name what you must
## collect, so this one names where it already is.
##
## Locked rows are dimmed rather than hidden. What a manufacturer is FOR is
## mostly what it does at 3 and 5 parts, so hiding those until you get there
## would hide the reason to pick it; greying them says "later" instead of
## "never", which is the actual state.
func _bonus(at: String, title: String, text: String, accent: Color,
		unlocked: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var tag := UITheme.body(at, accent if unlocked else UITheme.COLD, UITheme.FS_SMALL)
	tag.custom_minimum_size = Vector2(84, 0)
	row.add_child(tag)
	var name_col := UITheme.ICE if unlocked else UITheme.COLD
	var name_label := UITheme.body(title.to_upper(), name_col, UITheme.FS_SMALL)
	name_label.custom_minimum_size = Vector2(112, 0)
	row.add_child(name_label)
	var what := UITheme.body(text, UITheme.COLD if unlocked else UITheme.QUOTE,
		UITheme.FS_SMALL)
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(what)
	return row

## One weight class, as a line of text.
##
## These used to be three cards with the ship drawn on each, which put the same
## hull on screen twice — once large beside its attributes and once small down
## here. A picker does not have to show you the thing; it has to let you choose
## it, and the choice is between three sets of numbers that a list states more
## plainly than three pictures of very similar ships ever did.
func _weight_row(man: StringName, w: HullData.Weight, m: ManufacturerData) -> Button:
	var h := DB.hull_for(man, w)
	var chosen := w == _weight

	# Widgets.button for the sounds, as above.
	var btn := Widgets.button("", _pick_weight.bind(w))
	btn.flat = true
	btn.custom_minimum_size = Vector2(0, 15)
	var face := m.colour if chosen else Color(0, 0, 0, 0)
	var bg := m.field if chosen else Color(0, 0, 0, 0)
	btn.add_theme_stylebox_override("normal", UITheme.flat(bg, face, 0, 0, 4))
	btn.add_theme_stylebox_override("hover", UITheme.flat(m.field, m.colour, 0, 0, 4))
	btn.add_theme_stylebox_override("pressed", UITheme.flat(bg, m.colour, 0, 0, 4))
	btn.add_theme_stylebox_override("focus", UITheme.empty())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = ROW_INSET
	row.offset_right = -ROW_INSET

	var cls := UITheme.body(HullData.weight_name(w).to_upper(),
		m.colour if chosen else UITheme.COLD, UITheme.FS_SMALL)
	cls.custom_minimum_size = Vector2(52, 0)
	cls.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cls)

	# Class and name only. The stats that used to trail each row — hull, mounts,
	# cards — are all on screen for the SELECTED ship already, in the attribute
	# block, the hardpoints and the hand line. Printing them again for three
	# ships turned a picker into a comparison table nobody asked for, and the
	# comparison it offered was the one the attributes make better.
	var nm := UITheme.body(h.name.to_upper(),
		UITheme.ICE if chosen else UITheme.CHILL, UITheme.FS_SMALL)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(nm)

	btn.add_child(row)
	btn.tooltip_text = "%s\n%d hull · %d heat cap · %d dissipation\n%d weapon, %d system, %d utility mounts\n%d cards in hand" % [
		h.name, h.max_hull, h.heat_cap, h.dissipation,
		h.weapon_slots, h.system_slots, h.utility_slots, h.hand_size]
	return btn


## The manufacturer's banner, flown large.
##
## The same flag the cards carry down their left edge, at four times the scale
## and drawn by the same two functions — CardView.draw_cut for the hem and
## draw_emblem for the mark. Not a picture OF the card's banner; literally the
## card's banner, so a house whose hem gets redesigned is redesigned here too.
##
## Thirteen units wide because that is what the hems are authored against: the
## shapes use absolute offsets across the flag (Redline's tear is six two-unit
## strips), so a wider banner would leave them bunched at the left edge. Only
## the HEIGHT is free — the hem hangs off the bottom and the emblem sits near
## the top, and the plain field between them can be any length.
class Banner extends Control:
	const UNITS_W := 13
	const S := 3.0

	var man: StringName = &""
	var mark: Color = UITheme.CHILL
	var field: Color = UITheme.PANEL

	## Fixed across, free down. Thirteen units is what the hems are authored
	## against and cannot change; the height is whatever the header is, so the
	## flag hangs the full depth of the panel rather than stopping short of it
	## with a strip of background under the hem.
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(UNITS_W * S, 0)
		size_flags_vertical = Control.SIZE_FILL

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var b := Rect2(Vector2.ZERO, size)
		draw_rect(b, field, true)
		# UITheme.PANEL because that is what Widgets.panel_with paints behind
		# this. Most of the hems are CUT — carved by painting the background back
		# over the flag — so the wrong colour here does not misdraw a hem, it
		# makes it invisible.
		CardView.draw_cut(self, man, b, mark, UITheme.PANEL, S)
		CardView.draw_emblem(self, man, Vector2(b.size.x * 0.5, 11.0 * S), S, mark, field)
		# Outlined last, in the house's own mark dimmed. Two houses fly fields
		# that are nearly the panel's own colour — Redline's charcoal, Cygnet's
		# midnight — and without this their banners have no edge at all.
		var e := mark.darkened(0.35)
		var w := S
		draw_rect(Rect2(b.position, Vector2(b.size.x, w)), e, true)
		draw_rect(Rect2(Vector2(b.position.x, b.end.y - w), Vector2(b.size.x, w)), e, true)
		draw_rect(Rect2(b.position, Vector2(w, b.size.y)), e, true)
		draw_rect(Rect2(Vector2(b.end.x - w, b.position.y), Vector2(w, b.size.y)), e, true)


## A manufacturer's mark on a small dark plate. Nine by nine at 1x, which is the
## size CardView.draw_emblem's offsets are authored for.
class Badge extends Control:
	var man: StringName = &""
	var mark: Color = UITheme.CHILL
	var field: Color = UITheme.PANEL
	var scale_px: float = 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		var s := 13.0 * scale_px
		custom_minimum_size = Vector2(s, s)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var s := 13.0 * scale_px
		draw_rect(Rect2(Vector2.ZERO, Vector2(s, s)), field, true)
		draw_rect(Rect2(Vector2.ZERO, Vector2(s, s)), mark.darkened(0.3), false, 1.0)
		CardView.draw_emblem(self, man, Vector2(s, s) * 0.5, scale_px, mark, field)
