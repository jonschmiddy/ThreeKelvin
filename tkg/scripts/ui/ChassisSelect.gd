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

	root.add_child(UITheme.header("CHOOSE A CHASSIS"))

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
	# Scrolled, with LAUNCH pinned under it. Measured, the detail needs about
	# 457px against 445 available — and that was KORVAN, which does not have the
	# longest backstory. Trimming twelve pixels would fit one manufacturer and
	# cut off another, so the height is not something this screen gets to
	# assume. What it must guarantee is that the button is always reachable,
	# which is why that sits outside the scroll rather than at the end of it.
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

	var go := Widgets.button("LAUNCH", func() -> void: launched.emit())
	go.custom_minimum_size = Vector2(0, 22)
	col2.add_child(go)

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

## How far an unpicked manufacturer is faded. The selected one sits at full.
const DIM := 0.45

func _select(i: int) -> void:
	_sel = i
	_refit()
	for j in _rows.size():
		_rows[j].modulate = Color(1, 1, 1, 1.0 if j == i else DIM)
	_build_detail()

func _hover(i: int, on: bool) -> void:
	if i == _sel or i >= _rows.size():
		return
	_rows[i].modulate = Color(1, 1, 1, 1.0 if on else DIM)

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
	var perk: Dictionary = DB.hull_perks.get(Run.hull.perk_id, {})
	if not perk.is_empty():
		idc.add_child(_bonus("HULL", str(perk.name), str(perk.text), UITheme.CHILL))
	idc.add_child(_bonus("3+", m.set3_name, m.set3_text, m.colour))
	idc.add_child(_bonus("5+", m.set5_name, m.set5_text, m.colour))
	idc.add_child(UITheme.body(
		"Modules from this yard, plus the hull — you launch at %d of 3."
			% Run.manufacturer_count(man),
		m.colour, UITheme.FS_SMALL))
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
	shipcol.add_child(UITheme.body(Run.hull.name.to_upper(), UITheme.ICE, UITheme.FS_HEAD))
	shipcol.add_child(UITheme.body(
		"%s CHASSIS" % HullData.weight_name(Run.hull.weight).to_upper(),
		UITheme.COLD, UITheme.FS_SMALL))
	var chosen := ShipView.new()
	chosen.setup_preview(Run.hull, HERO_H, HERO_SCALE)
	shipcol.add_child(chosen)
	mid.add_child(shipcol)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 3)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	yard.add_child(UITheme.body("THIS YARD BUILDS", UITheme.COLD, UITheme.FS_SMALL))
	for w in WEIGHTS:
		yard.add_child(_weight_row(man, w, m))
	foot.add_child(yard)

	var kit := VBoxContainer.new()
	kit.add_theme_constant_override("separation", 1)
	kit.custom_minimum_size = Vector2(230, 0)
	kit.add_child(UITheme.body("YOU LAUNCH WITH", UITheme.COLD, UITheme.FS_SMALL))
	for mod in Run.installed:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 5)
		var st := UITheme.body(
			ModuleData.slot_name(mod.slot).to_upper(), UITheme.COLD, UITheme.FS_SMALL)
		st.custom_minimum_size = Vector2(46, 0)
		line.add_child(st)
		line.add_child(UITheme.body(mod.name, UITheme.ICE, UITheme.FS_SMALL))
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

func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## One set bonus: the threshold, its name, and what it does.
func _bonus(at: String, title: String, text: String, accent: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var tag := UITheme.body(at, accent, UITheme.FS_SMALL)
	tag.custom_minimum_size = Vector2(16, 0)
	row.add_child(tag)
	row.add_child(UITheme.body(title.to_upper(), UITheme.ICE, UITheme.FS_SMALL))
	var what := UITheme.body(text, UITheme.COLD, UITheme.FS_SMALL)
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
	row.offset_left = 5
	row.offset_right = -5

	var cls := UITheme.body(HullData.weight_name(w).to_upper(),
		m.colour if chosen else UITheme.COLD, UITheme.FS_SMALL)
	cls.custom_minimum_size = Vector2(52, 0)
	cls.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cls)

	var nm := UITheme.body(h.name.to_upper(),
		UITheme.ICE if chosen else UITheme.CHILL, UITheme.FS_SMALL)
	nm.custom_minimum_size = Vector2(140, 0)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(nm)

	var facts := UITheme.body(
		"%d hull · %d/%d/%d mounts · %d cards" % [
			h.max_hull, h.weapon_slots, h.system_slots, h.utility_slots, h.hand_size],
		UITheme.COLD, UITheme.FS_SMALL)
	facts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(facts)

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
	## Shortened from 58. The banner was the tallest thing in the header and set
	## its height on its own; at 50 the identity column beside it is the taller
	## of the two, so the flag costs nothing and the scrollbar appears less
	## often.
	const UNITS_H := 50
	const S := 3.0

	var man: StringName = &""
	var mark: Color = UITheme.CHILL
	var field: Color = UITheme.PANEL

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(UNITS_W, UNITS_H) * S
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	func _draw() -> void:
		var b := Rect2(Vector2.ZERO, Vector2(UNITS_W, UNITS_H) * S)
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
