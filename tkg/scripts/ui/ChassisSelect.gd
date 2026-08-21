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
## What each weight class IS, in one line, for the L/M/H tooltips. The buttons
## are single letters, so this is where the word and the trade-off live.
## One line each, in the same register as WEIGHT_BLURB: what the class buys you,
## not its numbers. The numbers are already on screen in the attribute block and
## the hardpoint rows, and clicking is how you compare them.
##
## SPECIFICATION, NOT CONDITION. These used to read "kept up", "well kept",
## "somebody loved this ship" — and that was wrong, because a class grows
## HARDPOINTS. A well-maintained ship does not sprout a weapon mount. How beaten
## up a hull is now lives on its hull points and is drawn by HullWear, which
## leaves these letters free to mean the thing they actually change.
const TIER_BLURB: Array[String] = [
	"Base specification. What every run starts on.",
	"Uprated frame. More hull and more heat capacity, same hardpoints.",
	"Line specification. Carries an extra weapon hardpoint.",
	"Top of the line. An extra weapon and system mount, and the reactor to run them.",
]

const WEIGHT_BLURB: Array[String] = [
	"Thin plate and the smallest hold, but it draws the biggest hand and can actually dodge.",
	"The middle of every axis, with no standout strength and no glaring weakness.",
	"The most plate and the biggest hold, and it cannot dodge or turn to save itself.",
]
## The one ship on the screen, and the only one drawn at all.
##
## Cropped to roughly the band the hull occupies, so the window throws away the
## empty rows above and below rather than the ship.
##
## 1x, not 2x. Integer scaling is the pixel-art rule, so a hull is either its own
## size or exactly double it and there is nothing in between — and double filled
## most of the panel once real art replaced the procedural drawing. ShipScreen
## carries the same note for the same reason.
const HERO_SCALE := 2
## Tall enough to hold the whole hull at HERO_SCALE. The canvas is cropped to 88
## rows, so 2x needs 176 plus room for the idle bob. The rows come from the
## weight picker moving up onto the hull's name line.
const HERO_H := 184
## The gap between the banner and the identity column, reused as the indent for
## everything below that has to line up with it.
## The air between ATTRIBUTES, HARDPOINTS and STARTING MODULES. One constant so
## the three read as evenly spaced blocks rather than as a list that happens to
## have gaps in it.
##
## Four, and it is measured against the WORST chassis rather than a typical one.
## Cygnet's light frame has four utility mounts, so it launches with seven
## modules where most launch with five — two extra rows in the list below. At a
## 12px gap that build came to 470px against a 448px viewport, and the 22px the
## ScrollContainer quietly absorbed read as the module list being cut off.
const BLOCK_GAP := 4

## Between the buttons in the weight row and the grade row, and it has to be the
## SAME number for both or the two rows stop lining up. See _tier_row.
const PICKER_GAP := 6

## Between those two rows. shipcol runs at separation 1 because the hull below it
## needs every pixel it can get, and two rows of buttons one pixel apart read as
## one crowded block rather than as two questions.
##
## PAID FOR, not added: the gap under the pair drops by the same amount, so the
## column is exactly as tall as it was. This screen was measured to 448 against a
## 448 viewport and has no slack to spend.
const PICKER_ROWS_GAP := 4
## What each row of the hardpoints block IS. Same shape as every other tooltip
## on this screen: the name, then one sentence. None of them restates the number
## sitting an inch to the left.
const MOUNT_TIP := {
	"weapon": "Weapon mounts
Where guns, launchers and charged ordnance bolt on. Each one grants two cards to your deck.",
	"system": "System mounts
Armour, coolant and shielding — the defensive half of a build. Each one grants two cards.",
	"utility": "Utility mounts
Masts, dishes, drone racks and sensors. The situational parts, and they grant one card rather than two.",
	"hand": "Hand
How many cards you are dealt at the start of each combat turn.",
	"hold": "Hold
Loose parts you can carry between fights. A full hold means leaving the next wreck where it lies.",
}
const HEAD_GAP := 12
## The identity header's height, held equal across all seven. Measured, not
## chosen. Was 169, then 155, now 145 — each drop bought vertical room the panel
## below needed. The cost is real: this is a MINIMUM, so makers whose backstory
## wraps past it grow their own header and the page shifts by that much when you
## click between them. See _build_detail.
const HEAD_H := 145
## The right-hand column, shared by the attribute block above and the loadout
## below so the two line up.
##
## The column is pinned to the right edge and its rows are left-aligned inside
## it, so this width is also what sets how far LEFT the block starts: narrowing
## it moves ATTRIBUTES, HARDPOINTS and STARTING MODULES rightward together,
## which is the only lever that moves all three without breaking the shared left
## edge they were given in the first place. The margin on `rwrap` cannot do it —
## that sits outside the column and pushes the column left, not its contents
## right.
##
## The widest row is MANEUVERABILITY's: its label, ten cells and a value, about
## 217px. 264 keeps roughly 45px of headroom over that.
const SIDE_W := 264
## How far the rows in the chassis list are inset inside their buttons, so a
## selected row's fill has a margin before its text. The list's heading uses it
## too, or the two do not share a left edge.
const ROW_INSET := 5

var _sel: int = 0
var _weight: HullData.Weight = HullData.Weight.MEDIUM
## The condition grade to launch on. DEV ONLY — a real run always starts at C,
## because a graded frame is something you cut out of a wreck. See _tier_row().
var _tier: int = 0
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
	_detail.add_theme_constant_override("separation", 3)
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
	var open := Unlocks.unlocked(man)
	var btn := Widgets.button("", _select.bind(i))
	btn.flat = true
	btn.custom_minimum_size = Vector2(0, 34)
	# A locked house still says WHAT IT IS. The identity line is the pitch, and it
	# is what makes a locked row a thing you want rather than a row you cannot
	# press. Only the NAME is withheld, and the line under it says what it costs.
	btn.tooltip_text = Widgets.tip("%s\n%s" % [m.name if open else "????", m.identity])
	if not open:
		btn.tooltip_text += Widgets.tip("\n\n%s" % Unlocks.lock_line(man))
		btn.disabled = true
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
	# Locked rows keep their SHAPE so the list still reads as seven houses rather
	# than one house and six gaps. Only the identifying marks are withheld.
	badge.man = man if open else &""
	badge.mark = m.colour if open else UITheme.QUOTE
	badge.field = m.field if open else UITheme.PANEL
	badge.scale_px = 2.0
	badge.locked = not open
	row.add_child(badge)

	var label := UITheme.body(
		DB.short_name(m.name).to_upper() if open else "????",
		m.colour if open else UITheme.QUOTE, UITheme.FS_HEAD)
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
	# A locked house is not flyable. The button is disabled too; this is the belt
	# to that braces, because _select is also called from setup() with a literal 0.
	if not Unlocks.unlocked(DB.STARTABLE[i]):
		return
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

func _pick_tier(t: int) -> void:
	_tier = t
	_refit()
	_build_detail()

func _refit() -> void:
	Run.fit_chassis(DB.STARTABLE[_sel], _weight, _tier)

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
	for row in Widgets.ability_rows(man, Run.hull.perk_id, Run.manufacturer_count(man)):
		idc.add_child(row)
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
	shipcol.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# The name and the weight picker share one line: the picker CHANGES the name
	# beside it, so putting them on the same baseline makes the cause and the
	# effect one glance apart. It also buys the hull below them three whole rows,
	# which is what lets the sprite run at 2x.
	var namerow := HBoxContainer.new()
	# PICKER_GAP, not 10. The weight row and the grade row below it are both
	# right-aligned rows of 22px buttons, so an IDENTICAL separation is what makes
	# them a grid: L lands over B, M over A, H over S, and the ragged left edge is
	# just the row that has one fewer choice. At two different separations they
	# were two rows of buttons that happened to be near each other.
	namerow.add_theme_constant_override("separation", PICKER_GAP)
	namerow.add_child(UITheme.body(Run.hull.name.to_upper(), UITheme.ICE, UITheme.FS_HEAD))
	var ngap := Control.new()
	ngap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ngap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	namerow.add_child(ngap)
	for w in WEIGHTS:
		namerow.add_child(_weight_button(man, w, m))
	shipcol.add_child(namerow)
	shipcol.add_child(_gap(PICKER_ROWS_GAP))
	shipcol.add_child(_tier_row(man, m))
	var chosen := ShipView.new()
	chosen.setup_preview(Run.hull, HERO_H, HERO_SCALE)
	chosen.bob(2)
	# The only screen that lights the engines. See ShipView._burning.
	chosen.burn()
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
	# Vertically too. The right-hand column is the taller of the two now, so the
	# ship was sitting at the top of a row with sixty-odd pixels of nothing under
	# it. Expanding hands that slack to the view, and STRETCH_KEEP_CENTERED then
	# centres the sprite in it on both axes.
	chosen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Dropped clear of the name and class above it. The hull is the subject of
	# this half of the screen and it was riding up against its own caption.
	shipcol.add_child(_gap(14 - PICKER_ROWS_GAP))
	shipcol.add_child(chosen)
	mid.add_child(shipcol)

	# Fixed width, and the same width the kit column below uses. Both sit at the
	# right of an HBox whose other child expands, so equal widths put ATTRIBUTES,
	# HARDPOINTS and YOU LAUNCH WITH on one column — they were three headings at
	# three different left edges before.
	var right := VBoxContainer.new()
	# 2, not 3. This column carries about eleven rows, so a pixel of separation
	# is ten pixels of height — which is exactly what the tallest chassis was
	# over by. Cheaper to take it from the spacing between rows than from the
	# header, which is shared by all seven and shifts the page when it moves.
	right.add_theme_constant_override("separation", 2)
	right.custom_minimum_size = Vector2(SIDE_W, 0)
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(UITheme.body("ATTRIBUTES", UITheme.COLD, UITheme.FS_SMALL))
	var block := AttrBlock.new()
	block.setup(Run.attributes(), m.colour)
	right.add_child(block)

	# Hardpoints, in the same cells the refit screen uses. Slot pressure is the
	# whole install-or-scrap decision later, so it should be countable here —
	# before you commit — rather than discovered on the first drop.
	right.add_child(_gap(BLOCK_GAP))
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
	right.add_child(_tipped(hand, str(MOUNT_TIP["hand"])))
	# Under the hand, because it is the same kind of fact: how much ship you get
	# to use at once, and how much you get to carry between fights.
	var hold := HBoxContainer.new()
	hold.add_theme_constant_override("separation", 6)
	var hol := UITheme.body("HOLD", UITheme.COLD, UITheme.FS_SMALL)
	hol.custom_minimum_size = Vector2(46, 0)
	hold.add_child(hol)
	# Slots, not modules. A slot is a place in the hold and a module is one of the
	# things that can sit in it — valuables are coming and will sit in the same
	# ones, so counting the hold in modules would name it after only half of what
	# it carries.
	hold.add_child(UITheme.body("%d slots" % Run.hull.cargo_slots,
		UITheme.CHILL, UITheme.FS_SMALL))
	right.add_child(_tipped(hold, str(MOUNT_TIP["hold"])))

	# The starting kit joins the other two blocks in this column rather than
	# sitting in a row of its own below. It was already landing at the same left
	# edge, so it read as the third block already — it just had the hero sprite's
	# full height of dead space above it. One column, one rhythm: BLOCK_GAP
	# between each heading and the block before it.
	right.add_child(_gap(BLOCK_GAP))
	var kit := VBoxContainer.new()
	kit.add_theme_constant_override("separation", 1)
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
	right.add_child(kit)

	# Indented off the ship. The column is right-aligned, so the margin pushes its
	# contents rightward inside their own 300px and opens a gap between the hull
	# and the numbers describing it.
	var rwrap := MarginContainer.new()
	rwrap.add_theme_constant_override("margin_left", 14)
	rwrap.size_flags_horizontal = Control.SIZE_SHRINK_END
	rwrap.add_child(right)
	mid.add_child(rwrap)
	_detail.add_child(_align(mid))

	# --- the three it builds, and what this one launches carrying. Side by side
	# because both are short lists and the panel is wide — stacked, they were
	# what pushed LAUNCH off the bottom of the screen.


## Indent to the manufacturer-name column: past the banner and the gap after it.
## Derived from the banner rather than typed, so widening the flag moves
## everything that lines up with it.
func _align(c: Control) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(Banner.UNITS_W * Banner.S) + HEAD_GAP)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(c)
	return m

## Give a row a tooltip whose HOVER TARGET is the row, not the column.
##
## A row in a VBox stretches to the full column width, so a bare tooltip on it
## fires from empty space well to the right of anything readable. The inner box
## shrinks to its content and owns the hover; the outer one is inert and holds
## the slack. Same two-box shape AttrBlock uses, and for the same reason.
static func _tipped(inner: Control, tip: String) -> Control:
	inner.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	inner.mouse_filter = Control.MOUSE_FILTER_STOP
	inner.tooltip_text = Widgets.tip(tip)
	var outer := HBoxContainer.new()
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(inner)
	var slack := Control.new()
	slack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(slack)
	return outer

## The most mounts of one kind any chassis in the game can reach.
##
## DERIVED, not typed. A heavy carries four weapon mounts and `DB.TIER_DELTA`
## grants an A-class frame a fifth and an S-class one a system mount on top —
## two tables that have both moved this month, and a literal here would go stale
## the first time either moves again and quietly re-ragged the column.
##
## Cached because it is asked once per hardpoint row per chassis and the answer
## cannot change inside a session.
static var _ceiling: int = 0

static func _mount_ceiling() -> int:
	if _ceiling > 0:
		return _ceiling
	var m := 1
	for frame: HullData in DB.hull_frames:
		for d: Dictionary in DB.TIER_DELTA:
			m = maxi(m, frame.weapon_slots + int(d.weapon))
			m = maxi(m, frame.system_slots + int(d.system))
			m = maxi(m, frame.utility_slots)
	_ceiling = m
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
	var pads := SlotPads.new()
	pads.setup(used, total, _mount_ceiling())
	row.add_child(pads)
	row.add_child(UITheme.body("%d/%d" % [used, total], UITheme.CHILL, UITheme.FS_SMALL))
	return _tipped(row, str(MOUNT_TIP[ModuleData.slot_name(slot)]))

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
			v.tooltip_text = Widgets.tip(c.name)
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

## The chassis line, and in Developer Mode the four grade buttons on the end of
## it. Same shape as the weight picker one line above: the buttons CHANGE the
## text beside them, so cause and effect stay one glance apart.
##
## They sit here rather than in the name row because that row already carries
## three buttons and the ship name at head size, and this screen has 448 pixels
## of height to spend and no slack — a fourth control there pushed the sprite
## below the fold. This line was a bare label with the whole width spare.
##
## NOT BUILT when Developer Mode is off, rather than hidden: a hidden Control
## still takes layout and focus order. The line then reads exactly as it always
## has, which is the point — a player has no grade to choose, because a run
## starts at C and every better frame is something you found.
func _tier_row(man: StringName, m: ManufacturerData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", PICKER_GAP)
	row.add_child(UITheme.body(
		"%s CHASSIS · %s TIER" % [
			HullData.weight_name(Run.hull.weight).to_upper(), Run.hull.tier_letter()],
		UITheme.COLD, UITheme.FS_SMALL))
	if not DevMode.enabled:
		return row
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	for t in HullData.TIER_NAMES.size():
		row.add_child(_tier_button(man, t, m))
	return row

## One grade button. Deliberately the same 22x20 face as a weight button — they
## are the same KIND of control (pick one of a short list, the ship changes
## under you), and two sizes would say they were not.
func _tier_button(man: StringName, t: int, m: ManufacturerData) -> Button:
	var chosen := t == _tier
	var btn := Widgets.button(String(HullData.TIER_NAMES[t]), _pick_tier.bind(t))
	btn.custom_minimum_size = Vector2(22, 20)
	var face := m.colour if chosen else UITheme.LINE
	var bg := m.field if chosen else UITheme.PANEL
	btn.add_theme_stylebox_override("normal", UITheme.flat(bg, face, 0, 3, 6))
	btn.add_theme_stylebox_override("hover", UITheme.flat(m.field, m.colour, 0, 3, 6))
	btn.add_theme_stylebox_override("pressed", UITheme.flat(m.field, m.colour, 0, 3, 6))
	btn.add_theme_stylebox_override("focus", UITheme.empty())
	btn.add_theme_color_override("font_color", m.colour if chosen else UITheme.COLD)
	btn.add_theme_color_override("font_hover_color", UITheme.ICE)
	btn.add_theme_font_size_override("font_size", UITheme.FS_SMALL)
	btn.tooltip_text = Widgets.tip("%s tier\n%s" % [
		HullData.TIER_NAMES[t], TIER_BLURB[t]])
	return btn


func _weight_button(man: StringName, w: HullData.Weight, m: ManufacturerData) -> Button:
	var h := DB.hull_for(man, w)
	var chosen := w == _weight

	# Widgets.button for the sounds, as everywhere else.
	# One letter. Three of these sit beside the hull's name, where a full word
	# each would crowd the only line on the screen that has to stay readable —
	# and the word is one hover away on the tooltip, together with what the class
	# actually costs you.
	var btn := Widgets.button(HullData.weight_name(w).to_upper().substr(0, 1),
		_pick_weight.bind(w))
	btn.custom_minimum_size = Vector2(22, 20)
	var face := m.colour if chosen else UITheme.LINE
	var bg := m.field if chosen else UITheme.PANEL
	btn.add_theme_stylebox_override("normal", UITheme.flat(bg, face, 0, 3, 6))
	btn.add_theme_stylebox_override("hover", UITheme.flat(m.field, m.colour, 0, 3, 6))
	btn.add_theme_stylebox_override("pressed", UITheme.flat(m.field, m.colour, 0, 3, 6))
	btn.add_theme_stylebox_override("focus", UITheme.empty())
	btn.add_theme_color_override("font_color", m.colour if chosen else UITheme.COLD)
	btn.add_theme_color_override("font_hover_color", UITheme.ICE)
	btn.add_theme_font_size_override("font_size", UITheme.FS_SMALL)
	# The word the button had to give up, and one sentence on what it costs you.
	# Nothing else: every stat that used to be here is already on screen for the
	# selected chassis, in the attribute block and the hardpoint rows, and
	# clicking is how you compare them.
	btn.tooltip_text = Widgets.tip("%s\n%s" % [
		HullData.weight_name(w), WEIGHT_BLURB[int(w)]])
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


## Hardpoint cells: filled steel is occupied, an ember outline is a free pad.
##
## Lives here now rather than on ShipScreen. The refit screen used to draw its
## mounts this way and became a drag-and-drop grid, so this is the only place
## left that wants a countable summary of the slots rather than the slots
## themselves — which is right, because this screen is choosing a chassis and
## that one is filling it.
class SlotPads extends Control:
	const CELL := Vector2(9, 11)
	const GAP := 2
	var used := 0
	var total := 0

	## `reserve` is width held for pads this row does not have.
	##
	## Without it the control is exactly as wide as the mounts it draws, so the
	## "2/4" beside it sat at a different left edge on every row — weapon four
	## pads out, utility one. The three figures are meant to be read down the
	## column against each other, which they cannot be while the column is ragged.
	func setup(u: int, t: int, reserve: int = 0) -> void:
		used = u
		total = t
		custom_minimum_size = Vector2(maxi(total, reserve) * (CELL.x + GAP), CELL.y)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		var y: float = floor((size.y - CELL.y) * 0.5)
		for i in total:
			var pos := Vector2(i * (CELL.x + GAP), y)
			if i < used:
				draw_rect(Rect2(pos, CELL), UITheme.COLD, true)
				draw_rect(Rect2(pos, Vector2(CELL.x, 1)), UITheme.CHILL, true)
				draw_rect(Rect2(pos, Vector2(1, CELL.y)), UITheme.CHILL, true)
			else:
				# Four filled rects, not draw_rect's outline mode. An unfilled
				# draw_rect strokes the BOUNDARY, so a 1px line straddles it and
				# rounds outward on some edges only — empty pads came out
				# visibly larger than the filled ones beside them.
				draw_rect(Rect2(pos, CELL), Color("#10161f"), true)
				var e := UITheme.EMBER
				draw_rect(Rect2(pos, Vector2(CELL.x, 1)), e, true)
				draw_rect(Rect2(pos + Vector2(0, CELL.y - 1), Vector2(CELL.x, 1)), e, true)
				draw_rect(Rect2(pos, Vector2(1, CELL.y)), e, true)
				draw_rect(Rect2(pos + Vector2(CELL.x - 1, 0), Vector2(1, CELL.y)), e, true)


## A manufacturer's mark on a small dark plate. Nine by nine at 1x, which is the
## size CardView.draw_emblem's offsets are authored for.
class Badge extends Control:
	var man: StringName = &""
	var mark: Color = UITheme.CHILL
	var field: Color = UITheme.PANEL
	var scale_px: float = 1.0
	## Draw a question mark instead of the house's emblem. An emblem IS the
	## identity, so showing one on a house you have not earned would give the
	## answer away in the one place the name is being withheld.
	var locked: bool = false

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
		if locked:
			_question(s)
			return
		CardView.draw_emblem(self, man, Vector2(s, s) * 0.5, scale_px, mark, field)

	## A question mark in rects, at the emblem's own scale. Drawn rather than
	## typed because every mark beside it is drawn, and a font glyph at this size
	## sits on a different baseline and reads as a different KIND of thing than
	## the emblems it is standing in for.
	func _question(s: float) -> void:
		var u := scale_px
		var x := s * 0.5 - u * 1.5
		var y := s * 0.5 - u * 3.5
		for r in [
			Rect2(x, y, u * 3.0, u),                    # top bar
			Rect2(x + u * 2.0, y + u, u, u * 2.0),      # right shoulder
			Rect2(x + u, y + u * 3.0, u * 2.0, u),      # the turn inward
			Rect2(x + u, y + u * 4.0, u, u),            # stem
			Rect2(x + u, y + u * 6.0, u, u),            # the dot
		]:
			draw_rect(r, mark, true)
