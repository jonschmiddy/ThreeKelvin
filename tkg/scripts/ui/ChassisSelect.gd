class_name ChassisSelect
extends Control

## Two axes: manufacturer is who you are, weight class is how much ship.
## Selecting really refits (`Run.fit_chassis()`), so there is no second calculation to drift.
## Why: docs/why/ChassisSelect.md#chassis-select

signal launched

const WEIGHTS := [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]
## One line on what a class buys, not its numbers, which are already on screen.
## Specification, not condition: a class grows hardpoints, and wear lives in `HullWear`.
## Why: docs/why/ChassisSelect.md#tier-blurbs
const TIER_BLURB: Array[String] = [
	"The base specification that every run starts on.",
	"An uprated frame with more hull and heat capacity, on the same hardpoints.",
	"The line specification, with an extra weapon hardpoint.",
	"The top model, with an extra weapon and system mount and the reactor to run them.",
]

const WEIGHT_BLURB: Array[String] = [
	"Thin plate and the smallest hold, but it draws the biggest hand and can dodge.",
	"In the middle on every stat, with no big strength and no big weakness.",
	"The most plate and the biggest hold, but it cannot dodge at all.",
]
## 1x, not 2x: hulls are authored at 2x their box, so drawing at 2x applies it twice (boxes.py).
## Integer scaling is the pixel-art rule. ShipScreen carries the same note.
## Why: docs/why/ChassisSelect.md#hero-scale
const HERO_SCALE := 1
## Derived from the deepest hull (140 rows) plus the bob, so it must move with the art.
const HERO_H := 160
## Gap of four, measured against the worst chassis: Cygnet's light launches with seven modules.
## At a 12px gap it came to 470px against 448, and the scroll hid the module list.
## Why: docs/why/ChassisSelect.md#layout-spacing
const BLOCK_GAP := 4

## Between the buttons in the weight row and the grade row, and it has to be the
## SAME number for both or the two rows stop lining up. See _tier_row.
const PICKER_GAP := 6

## Two button rows need a gap or they read as one block. Paid for from the gap under the pair.
## The screen is measured to 448 of 448, so there is no slack.
## Why: docs/why/ChassisSelect.md#layout-spacing
const PICKER_ROWS_GAP := 4
## The name, then one sentence, never restating the number beside it.
const MOUNT_TIP := {
	"weapon": "Weapon mounts
Where guns, launchers and charged ordnance bolt on. Each one grants two cards to your deck.",
	"system": "System mounts
Armour, coolant and shielding — the defensive half of a build. Each one grants two cards.",
	"utility": "Utility mounts
Masts, dishes, drone racks and sensors. The situational parts, and they grant two cards like everything else.",
	"hand": "Hand
How many cards you are dealt at the start of each combat turn.",
	"hold": "Hold
Loose parts you can carry between fights. A full hold means leaving the next wreck where it lies.",
	"reactor": "Reactor
Total cells of hardware this frame can RUN. The hold is what you can haul; this is what you can power, and a part has to satisfy both.",
}
const HEAD_GAP := 12
## A measured minimum (169, 155, now 145): long backstories grow their header and shift the page.
const HEAD_H := 145
## Column width also sets how far left the block starts. The `rwrap` margin cannot move contents.
## The widest row is MANEUVERABILITY's at about 217px, so 264 keeps 45px of headroom.
## Why: docs/why/ChassisSelect.md#layout-spacing
const SIDE_W := 264

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
	# NO SCIENCE CLEARED HERE.
	# Why: docs/why/ChassisSelect.md#no-science-cleared-here
	_build()
	_select(0)


func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 5)
	add_child(root)

	# Title left, LAUNCH right: always visible and in one place, not below a scroll.
	# Why: docs/why/ChassisSelect.md#launch-button
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(UITheme.header("CHOOSE A CHASSIS"))
	var tgap := Control.new()
	tgap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tgap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(tgap)
	# Silent: launching is the start of the game, not a UI click (Jon).
	var go := Widgets.button("LAUNCH", func() -> void: launched.emit(), false)
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
		var r := _manufacturer_row(i)
		_rows.append(r)
		_list.add_child(r)
	split.add_child(Widgets.panel_with(_list))

	# --- right: how much of it
	# Scrolled: detail needs about 457px of 445, and that was Korvan, not the longest backstory.
	# LAUNCH stays in the title row so it cannot scroll away.
	# Why: docs/why/ChassisSelect.md#detail-scroll
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

## Emblem and name only: the hull name belongs beside its hull, and there are three.
func _manufacturer_row(i: int) -> Button:
	var manufacturer: StringName = DB.STARTABLE[i]
	var m: ManufacturerData = DB.manufacturers[manufacturer]

	# Use `Widgets.button`: it wires every click and hover sound, which `Button.new()` skipped.
	var open := Unlocks.unlocked(manufacturer)
	var btn := Widgets.button("", _select.bind(i))
	btn.flat = true
	btn.custom_minimum_size = Vector2(0, 34)
	# A locked row still says what it is, as the pitch makes it wanted. Only the name is withheld.
	btn.tooltip_text = Widgets.tip("%s\n%s" % [m.name if open else "????", m.identity])
	if not open:
		btn.tooltip_text += Widgets.tip("\n\n%s" % Unlocks.lock_line(manufacturer))
		btn.disabled = true
	# Hover fills with the secondary colour, so seven rows light up in their own livery.
	btn.add_theme_stylebox_override("normal", UITheme.flat(UITheme.PANEL, UITheme.LINE, 0, 0, 4))
	btn.add_theme_stylebox_override("hover", UITheme.flat(m.field, m.colour, 0, 0, 4))
	btn.add_theme_stylebox_override("pressed", UITheme.flat(m.field, m.colour, 0, 0, 4))
	btn.add_theme_stylebox_override("focus", UITheme.empty())
	# The stylebox alone was invisible on dimmed rows (Redline), so hover restores opacity.
	btn.mouse_entered.connect(func() -> void: _hover(i, true))
	btn.mouse_exited.connect(func() -> void: _hover(i, false))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 5
	row.offset_right = -5

	var badge := Badge.new()
	# Locked rows keep their SHAPE so the list still reads as seven manufacturers rather
	# than one manufacturer and six gaps. Only the identifying marks are withheld.
	badge.manufacturer = manufacturer if open else &""
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

## Cooled and darkened, not just alpha: modulate multiplies, so a dimmed Redline still read red.
## Why: docs/why/ChassisSelect.md#dim-colour
const DIM := Color(0.62, 0.66, 0.74, 0.42)
const LIT := Color(1, 1, 1, 1)

func _select(i: int) -> void:
	# A locked manufacturer is not flyable. The button is disabled too; this is the belt
	# to that braces, because _select is also called from setup() with a literal 0.
	if not Unlocks.unlocked(DB.STARTABLE[i]):
		return
	# The popup is a child of this screen, so rebuilding the detail does not close it.
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
	Widgets.clear(_detail)
	var manufacturer: StringName = DB.STARTABLE[_sel]
	var m: ManufacturerData = DB.manufacturers[manufacturer]

	# --- who built it. The banner the cards fly, four times the size.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", HEAD_GAP)

	var flag := Banner.new()
	flag.manufacturer = manufacturer
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
	# Set bonuses are this manufacturer's strategy, so they sit under its name.
	idc.add_child(UITheme.body("MANUFACTURER ABILITIES", UITheme.COLD, UITheme.FS_SMALL))
	# The perk is a hull property: `LootGen` rerolls it on wrecks, so the tag reads HULL, not 1+.
	# Why: docs/why/ChassisSelect.md#hull-perk
	for row in Widgets.ability_rows(manufacturer, Run.hull.perk_id, Run.manufacturer_count(manufacturer)):
		idc.add_child(row)
	# The rows state where this ship starts on the count, not the arithmetic: how close you are.
	# No running count: at chassis choice it is always two. It belongs on the ship screen.
	# Why: docs/why/ChassisSelect.md#ability-rows
	head.add_child(idc)
	# One height for every manufacturer: clicking down the list shifted the page 14px (155 vs 169).
	# A minimum, so longer prose pushes into the scroll instead of being clipped.
	# Why: docs/why/ChassisSelect.md#header-height
	head.custom_minimum_size.y = HEAD_H
	_detail.add_child(head)

	_detail.add_child(UITheme.hsep())

	# --- what you are flying, and what it comes to on the six axes.
	# Indented to clear the banner, so the hull name shares the manufacturer name's column.
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 14)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# The only place the ship is drawn: the picker below is a list, as two pictures were one fact.
	var shipcol := VBoxContainer.new()
	shipcol.add_theme_constant_override("separation", 1)
	shipcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shipcol.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Picker beside the name it changes, so cause and effect are one glance apart. Buys three rows.
	var namerow := HBoxContainer.new()
	# Same `PICKER_GAP` as the grade row below, so L/B, M/A, H/S line up as a grid.
	namerow.add_theme_constant_override("separation", PICKER_GAP)
	namerow.add_child(UITheme.body(Run.hull.name.to_upper(), UITheme.ICE, UITheme.FS_HEAD))
	var ngap := Control.new()
	ngap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ngap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	namerow.add_child(ngap)
	for w in WEIGHTS:
		namerow.add_child(_weight_button(w, m))
	shipcol.add_child(namerow)
	shipcol.add_child(_gap(PICKER_ROWS_GAP))
	shipcol.add_child(_tier_row(manufacturer, m))
	var chosen := ShipView.new()
	chosen.setup_preview(Run.hull, HERO_H, HERO_SCALE)
	chosen.bob(2)
	# The only screen that lights the engines. See ShipView._burning.
	chosen.burn()
	# The ship asks for no width and takes what is left: at 2x, 480px overflowed the panel.
	# The backstory losing its last word was this, not a text problem.
	# Why: docs/why/ChassisSelect.md#hull-sizing
	chosen.custom_minimum_size.x = 0
	chosen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Expands vertically too: the right column is taller, so the slack goes to the view, centred.
	chosen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Dropped clear of the name and class above it. The hull is the subject of
	# this half of the screen and it was riding up against its own caption.
	shipcol.add_child(_gap(14 - PICKER_ROWS_GAP))
	shipcol.add_child(chosen)
	mid.add_child(shipcol)

	# Same fixed width as the kit column, so ATTRIBUTES, HARDPOINTS and YOU LAUNCH WITH align.
	var right := VBoxContainer.new()
	# Separation 2, not 3: about eleven rows make a pixel ten of height.
	right.add_theme_constant_override("separation", 2)
	right.custom_minimum_size = Vector2(SIDE_W, 0)
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(UITheme.body("ATTRIBUTES", UITheme.COLD, UITheme.FS_SMALL))
	var block := AttrBlock.new()
	# Shows the real hull after HULL's pips (ruling 12 C), as the HUD's HULL is too far away.
	block.setup(Run.attributes(), m.colour, true)
	right.add_child(block)

	# Slot pressure drives the later install-or-scrap choice, so it is countable before committing.
	right.add_child(_gap(BLOCK_GAP))
	right.add_child(UITheme.body("HARDPOINTS", UITheme.COLD, UITheme.FS_SMALL))
	for s in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]:
		right.add_child(_mount_row(s))
	# Under the mounts: the other thing that can refuse a part, which a player cannot guess.
	# `hull.power_cap`, not `power_cap()`: this screen describes a frame, not the loadout on it.
	# Why: docs/why/ChassisSelect.md#power-cap
	var rct := HBoxContainer.new()
	rct.add_theme_constant_override("separation", 6)
	var rl := UITheme.body("REACTOR", UITheme.COLD, UITheme.FS_SMALL)
	rl.custom_minimum_size = Vector2(46, 0)
	rct.add_child(rl)
	rct.add_child(UITheme.body("%d cells" % Run.power_cap(),
		UITheme.CHILL, UITheme.FS_SMALL))
	right.add_child(_tipped(rct, str(MOUNT_TIP["reactor"])))
	# Hand size sits with the hardpoints: not an attribute, as nothing checks against it.
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
	# Slots, not modules: valuables are coming and will sit in the same slots.
	hold.add_child(UITheme.body("%d slots" % Run.hull.cargo_slots,
		UITheme.CHILL, UITheme.FS_SMALL))
	right.add_child(_tipped(hold, str(MOUNT_TIP["hold"])))

	# The kit joins the column, not its own row: one column, one rhythm of `BLOCK_GAP`.
	right.add_child(_gap(BLOCK_GAP))
	var kit := VBoxContainer.new()
	kit.add_theme_constant_override("separation", 1)
	var kit_head := HBoxContainer.new()
	kit_head.add_theme_constant_override("separation", 8)
	kit_head.add_child(UITheme.body("STARTING MODULES", UITheme.COLD, UITheme.FS_SMALL))
	# The modules are fiction, the deck is what you play: nine cards answer how turns will feel.
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
		# Named in rarity colour, so the one branded weapon stands out among Common steel.
		line.add_child(UITheme.body(mod.name,
			ModuleData.rarity_ink(mod.rarity), UITheme.FS_SMALL))
		kit.add_child(line)
	right.add_child(kit)

	# Indented off the ship: the margin opens a gap between the hull and its numbers.
	var rwrap := MarginContainer.new()
	rwrap.add_theme_constant_override("margin_left", 14)
	rwrap.size_flags_horizontal = Control.SIZE_SHRINK_END
	rwrap.add_child(right)
	mid.add_child(rwrap)
	_detail.add_child(_align(mid))

	# --- the three it builds, and what this one launches carrying. Side by side
	# Side by side: stacked, the two lists pushed LAUNCH off the bottom of the screen.


## Derived from the banner, not typed, so widening the flag moves everything lined up with it.
func _align(c: Control) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(Banner.UNITS_W * Banner.S) + HEAD_GAP)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(c)
	return m

## A bare tooltip on a full-width row fires from empty space. The inner box owns the hover.
## Same two-box shape as AttrBlock, for the same reason.
## Why: docs/why/ChassisSelect.md#row-tooltips
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

## Derived, not typed: `DB.TIER_DELTA` and heavy mounts moved this month, so a literal goes stale.
## Cached: asked once per row per chassis and it cannot change in a session.
## Why: docs/why/ChassisSelect.md#mount-ceiling
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

## Built from `Run.installed`, so it cannot disagree with the deck you actually launch with.
## Why: docs/why/ChassisSelect.md#deck-popup
func _show_deck() -> void:
	if _deck_pop != null:
		return
	# Popup sized to the cards: a full-screen sheet reads as leaving the screen.
	# Anywhere outside the panel dismisses it.
	var centre := Widgets.prompt(self, _close_deck, 0.72)
	_deck_pop = centre.get_parent() as Control

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
			# STOP plus a non-empty `tooltip_text` makes Godot ask CardView for the hand's readout.
			v.mouse_filter = Control.MOUSE_FILTER_STOP
			v.tooltip_text = Widgets.tip(c.name)
			flow.add_child(v)
	# Capped at two rows of cards. A deck that outgrows it scrolls rather than
	# pushing the panel off the top and bottom of the screen.
	col.add_child(Widgets.scroller(flow, CardView.CARD_H * 2 + 5))

	var pad := Widgets.pad(null, 12, 10)
	pad.add_child(col)
	centre.add_child(Widgets.panel_with(pad))

func _close_deck() -> void:
	if _deck_pop == null:
		return
	_deck_pop.queue_free()
	_deck_pop = null


## Esc goes back to the title, not the escape menu (tutorial audit, Oct 22).
## Its ABANDON put a run that never started on the record.
## Why: docs/why/ChassisSelect.md#escape-handling
func escape() -> void:
	if _deck_pop != null:
		_close_deck()
		return
	Run.hull = null
	Router.show_launcher()

var _deck_pop: Control = null

func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## Developer Mode only, on the chassis line: the name row had no height left for a fourth control.
## Not built when off, rather than hidden: a hidden Control still takes layout and focus.
## Why: docs/why/ChassisSelect.md#grade-buttons
func _tier_row(manufacturer: StringName, m: ManufacturerData) -> Control:
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
		row.add_child(_tier_button(t, m))
	return row

## Same 22x20 face as a weight button: the same kind of control, and two sizes would deny it.
func _tier_button(t: int, m: ManufacturerData) -> Button:
	var btn := _livery_button(String(HullData.TIER_NAMES[t]), _pick_tier.bind(t), t == _tier, m)
	btn.tooltip_text = Widgets.tip("%s tier\n%s" % [
		HullData.TIER_NAMES[t], TIER_BLURB[t]])
	return btn


func _weight_button(w: HullData.Weight, m: ManufacturerData) -> Button:
	# One letter, as three sit beside the hull name. The word is one hover away.
	var btn := _livery_button(HullData.weight_name(w).to_upper().substr(0, 1),
		_pick_weight.bind(w), w == _weight, m)
	# The word and one sentence of cost only: every stat is on screen for the selected chassis.
	btn.tooltip_text = Widgets.tip("%s\n%s" % [
		HullData.weight_name(w), WEIGHT_BLURB[int(w)]])
	return btn


## The small chip a tier or weight picker is made of, in the manufacturer's livery when chosen.
func _livery_button(label: String, on_press: Callable, chosen: bool, m: ManufacturerData) -> Button:
	var btn := Widgets.button(label, on_press)
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
	return btn


## The card's own flag at four times scale, via `CardView.draw_cut` and `draw_emblem`.
## Thirteen units wide: hems use absolute offsets across the flag. Only the height is free.
## Why: docs/why/ChassisSelect.md#banner
class Banner extends Control:
	const UNITS_W := 13

	## Depth measured off what the draws put on it, plus a unit of air.
	## Only a minimum: on chassis cards the flag hangs the header's full depth.
	## Why: docs/why/ChassisSelect.md#banner
	const UNITS_H := 22
	const S := 3.0

	## Pixels per unit per instance, so every offset scales together and a hem gets no hole.
	## Set it before adding the banner, with `custom_minimum_size`: `_init` cannot see it.
	## Why: docs/why/ChassisSelect.md#banner
	var s: float = S

	## Setting the manufacturer arms the tooltip: Godot asks only if `tooltip_text` is non-empty.
	var manufacturer: StringName = &"":
		set(value):
			manufacturer = value
			var m: ManufacturerData = DB.manufacturers.get(value)
			if m == null:
				return
			tooltip_text = m.name.to_upper()
			# PASS, not STOP: a banner in a clickable card must hand the press on and still hover.
			mouse_filter = Control.MOUSE_FILTER_PASS
	var mark: Color = UITheme.CHILL
	var field: Color = UITheme.PANEL

	## Fixed across (13 units), free down, so the flag hangs the panel's full depth.
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(UNITS_W * S, 0)
		size_flags_vertical = Control.SIZE_FILL

	## The same rich-panel hook `ModuleIcon`, `CardView` and `PerkBox` use.
	func _make_custom_tooltip(_for_text: String) -> Object:
		return Widgets.manufacturer_readout(manufacturer)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var b := Rect2(Vector2.ZERO, size)
		draw_rect(b, field, true)
		# `UITheme.PANEL`: most hems are cut by painting the background back over the flag.
		CardView.draw_cut(self, manufacturer, b, mark, UITheme.PANEL, s)
		CardView.draw_emblem(self, manufacturer, Vector2(b.size.x * 0.5, 11.0 * s), s, mark, field)
		# Outlined in the dimmed mark: Redline's and Cygnet's fields are nearly the panel colour.
		var e := mark.darkened(0.35)
		var w := s
		draw_rect(Rect2(b.position, Vector2(b.size.x, w)), e, true)
		draw_rect(Rect2(Vector2(b.position.x, b.end.y - w), Vector2(b.size.x, w)), e, true)
		draw_rect(Rect2(b.position, Vector2(w, b.size.y)), e, true)
		draw_rect(Rect2(Vector2(b.end.x - w, b.position.y), Vector2(w, b.size.y)), e, true)


## Lives here now: the refit screen became drag and drop, so only this screen wants a slot summary.
## Why: docs/why/ChassisSelect.md#slot-pads
class SlotPads extends Control:
	const CELL := Vector2(9, 11)
	const GAP := 2
	var used := 0
	var total := 0

	## `reserve` is width for pads this row lacks, so the figures share a left edge.
	## Why: docs/why/ChassisSelect.md#slot-pads
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
				# Four filled rects, not outline mode: a 1px stroke drew empty pads larger.
				draw_rect(Rect2(pos, CELL), Color("#10161f"), true)
				var e := UITheme.EMBER
				draw_rect(Rect2(pos, Vector2(CELL.x, 1)), e, true)
				draw_rect(Rect2(pos + Vector2(0, CELL.y - 1), Vector2(CELL.x, 1)), e, true)
				draw_rect(Rect2(pos, Vector2(1, CELL.y)), e, true)
				draw_rect(Rect2(pos + Vector2(CELL.x - 1, 0), Vector2(1, CELL.y)), e, true)


## A manufacturer's mark on a small dark plate. Nine by nine at 1x, which is the
## size CardView.draw_emblem's offsets are authored for.
class Badge extends Control:
	var manufacturer: StringName = &""
	var mark: Color = UITheme.CHILL
	var field: Color = UITheme.PANEL
	var scale_px: float = 1.0
	## A question mark instead of the emblem: an emblem is the identity and would give it away.
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
		CardView.draw_emblem(self, manufacturer, Vector2(s, s) * 0.5, scale_px, mark, field)

	## Drawn in rects like the emblems: a font glyph sits on another baseline.
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
