class_name ShipScreen
extends Control

## Refit, as a workbench.
##
## The ship and what it IS on the left; the parts and where they go on the
## right. You drag a module from storage onto a hardpoint to fit it, drag it
## back to store it, and drop one onto an occupied mount to swap the two.
##
## There is no melter on this screen. Scrapping a part still exists and still
## pays scrap — it lives on the station and the salvage prompt, where a bid to
## compare it against is also on screen. A drag-to-destroy target sitting next to
## the storage grid made the destructive move the easiest one to reach by
## accident, which is the wrong ergonomics for the only irreversible verb here.
##
## Modules are icons rather than rows. A list of names is a document; a grid of
## icons is an inventory, and this screen's whole job is the second thing —
## comparing what is bolted on against what is in the hold, at a glance, and
## moving one to the other. The rows it replaced could not show you a full
## weapon rack and a full hold at the same time.
##
## Two drop handlers, because there are two destinations asking different
## questions. `_on_mount_drop` asks whether a slot type matches and which PLACE
## on the hull was aimed at; `_on_hold_drop` asks whether a shape fits and at
## which cell. Nothing else in here touches `installed` or `cargo`.

## SUPERSEDED by HoldGrid, which takes its shape from HullData.hold_grid. Kept
## as the record of why four: the measurement below is what set it and it is
## still what the hold is drawn at.
##
## Four across, so the hold reads as rows of four whatever hull you are flying.
##
## Capacities are 8 / 12 / 16, so four columns is exactly 2, 3 and 4 full rows —
## no ragged last row on any ship in the game, and the shape itself tells you
## which weight class you are in.
##
## Width is also why this is safe. Measured at eight columns the two panels
## demanded 985px of a 944px viewport and the melter and the last storage column
## hung off the right edge. The left panel cannot give any of it back — its 527px
## is the banner plus the ship at 2x, and the ship is the subject. Four columns
## is 201px against six columns' 303px, so the grid now costs a third of what it
## did when it did not fit.
## The ship panel's height, at 2x, off the SPEC rather than off whatever hull
## happens to exist: the largest class is 125x50, so 100 rows plus the bob.
##
## Deliberately SHORTER than the canvas, which is 122 rows at 2x once the 38px
## of exhaust clearance and the 11 of padding are doubled. Those rows are empty
## by construction, and cropping them is what buys the manufacturer abilities a
## place on the panel. Was 240, sized against art that is being replaced.
const HULL_VIEW_H := 166

## Clearance between the name block and the ship. The mount markers draw ABOVE
## the hull's own top edge — they are what a part bolts to, so they have to sit
## proud of it — and without this the dorsal row lands in the class line.
##
## 26 rather than the 10 that was merely enough to stop the collision: this is
## also the gap that sets how far down the panel the ship sits, and the flag
## beside it grows to match.
const HEAD_GAP := 0

## How wide the numbers get before the hold starts. Fixes the hold's top-left
## corner, which is the whole point: a hold grows by gaining CELLS, and it
## should gain them down and to the right, the way a hold fills. Right-aligned
## instead — which is where it sat first — a wider hold grew LEFTWARDS into the
## attributes, so the same five parts moved every time the ship changed.
##
## The panel gives 479px between its paddings and the attribute rows measure
## 183 of it, so this is mostly gutter. 220 puts the hold's left edge at x=254 —
## a 50px gutter off the numbers, which is enough to read as a separate block
## without being a hole.
##
## Sitting this far left is also what makes "grows down and to the right" true
## rather than aspirational: 245px of clear panel to the right of a five-wide
## hold is nine more columns. It was at 340 for one pass, and there the same
## sentence bought exactly one.
const STATS_W := 220

## Air between the hold's heading and its first row of cells, matched to the gap
## ATTRIBUTES has over HULL. That one is free — a label carries its own leading
## and the gauge row is mostly whitespace — and the hold's first row is a
## hard-edged plate, so the same distance has to be put there on purpose.
##
## MEASURED, not guessed: ATTRIBUTES clears HULL by 8px of background, and at
## LABEL_AIR 6 the hold cleared its grid by 11. Hence 3.
## Between the flag and the text beside it. Named because the ship's own
## placement has to subtract it — see `_centre_ship`.
## The left panel's width, fixed. See `_centre_ship` for why it cannot float.
##
## 524 is the smallest that fits everything: the manufacturer abilities want 470
## across, and a centred heavy needs the flag's 49 plus half a 336px view plus
## the 33 the hull sits off its own centre, which is 500 inside the padding.
const PANEL_W := 524

## What Widgets.panel_with insets its child by, on each side.
const PANEL_PAD := 12

const HEADER_SEP := 10

const LABEL_AIR := 3

## NO EXPLICIT GAP under the ship, and that is measured rather than an omission.
## The flag ends 8px above the ATTRIBUTES glyphs on its own: two of the column's
## separations, plus the leading a label carries above its own capitals. Adding a
## spacer of the 8 that was wanted produced 16.
##
## 8 is also what ATTRIBUTES clears HULL by and what the hold's heading clears
## its grid by, so all three headings on this panel now sit the same distance
## under whatever is above them.

const STORAGE_COLS := 4

## The pad that places the ship, and the panel it is placed against.
var _padl: Control
var _panel: Control
var _storage: HoldGrid
var _attrs: AttrBlock
var _mounts: VBoxContainer
var _mountpts: MountPoints
var _view: ShipView
var _banner: ChassisSelect.Banner
var _name: Label
var _maker: Label
var _class: Label
var _hand: Label
var _hold: Label
var _abilities: VBoxContainer

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	Sig.ship_changed.connect(_refresh)
	Sig.resources_changed.connect(_refresh)
	_refresh()

func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 5)
	add_child(root)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	# --- left: what you are flying
	var left := VBoxContainer.new()
	# 2, not 4. This column carries ten blocks and every pixel of separation is
	# ten pixels of height — which was the difference between the manufacturer
	# abilities being on the panel and being under it.
	left.add_theme_constant_override("separation", 2)

	# THE FLAG HANGS THE WHOLE DEPTH OF THE SHIP, name and hull both.
	#
	# This went the other way for a while — a short banner sized to the three
	# lines of text — because "fixed across, free down" meant it grew to the
	# ship's height and took vertical the blocks below needed. That was the
	# right diagnosis of the wrong problem: the vertical was won back by moving
	# the hold out of the column, and the flag can have its depth now.
	#
	# It is the one thing on this panel that says whose yard built what you are
	# looking at, and a 66px badge beside a 106px ship reads as a bullet point
	# next to the subject rather than as a masthead over it.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", HEADER_SEP)
	_banner = ChassisSelect.Banner.new()
	# The minimum is the flag's AUTHORED depth (Banner.UNITS_H); FILL is what
	# takes it the rest of the way down. The two together mean the hem is never
	# cut off no matter how short the row gets, and the flag still reaches the
	# bottom of the ship when there is room.
	_banner.custom_minimum_size = ChassisSelect.Banner.S * Vector2(
		ChassisSelect.Banner.UNITS_W, ChassisSelect.Banner.UNITS_H)
	_banner.size_flags_vertical = Control.SIZE_FILL
	header.add_child(_banner)

	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 1)
	# EXPANDING, or the ship's centring pads have nothing to divide. Without
	# this the column is only as wide as its widest child, so the row holding
	# the ship shrink-wrapped it and both pads came out zero — the ship sat
	# hard against the flag and every correction below did nothing.
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name = UITheme.body("", UITheme.ICE, UITheme.FS_HEAD)
	names.add_child(_name)
	_maker = UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)
	names.add_child(_maker)
	_class = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	names.add_child(_class)
	header.add_child(names)

	# AIR UNDER THE NAME. The ship's mount markers draw above the hull's own
	# top edge, so a ship butted straight against the header put hardpoints
	# through the "HEAVY CHASSIS - S TIER" line. Fixed rather than a spacer that
	# shares in the column's slack: this gap is clearance, and clearance that
	# gives way under pressure is not clearance.
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, HEAD_GAP)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(gap)

	# The banner hangs the full depth of the ship rather than a badge sitting
	# beside a name. It is the same flag the chassis cards fly and it is the one
	# piece of this panel that says whose yard built the thing you are looking
	# at, so it gets the height the subject has — a 26px badge next to two lines
	# of text read as a bullet point.
	var shiprow := HBoxContainer.new()
	shiprow.add_theme_constant_override("separation", 8)

	# Doubled and cropped to the hull, the same treatment the chassis select
	# gives it. At 1x in a panel this size the ship was a small object adrift in
	# a lot of nothing, which is the wrong impression for the screen whose
	# subject it is. SHRINK_CENTER inside an expanding wrapper puts it in the
	# middle of the space the banner leaves rather than hard against the flag.
	var view := ShipView.new()
	# 2x. Integer scaling is the whole pixel-art rule, so the ship is either its
	# own size or exactly double and there is nothing in between. 184 rows: the
	# canvas is cropped to 88, doubling needs 176, plus bob headroom.
	# 1x, not 2x, and the height sized off the TALLEST hull rather than the one
	# that used to be the only one.
	#
	# 2x was set when every hull was procedural at 240x120 and the one real
	# sprite was 188x88. The generated hulls run to 235x114, so 2x put a 470px
	# ship on a 960px canvas — half the screen — and 184 rows clipped the top and
	# bottom off the deepest ones. Integer magnification is the art rule and 1x
	# is the only step below 2x, so this is half rather than a nudge; at the
	# viewport's own 2x it is still two real pixels per art pixel and crisp.
	view.magnify(2, HULL_VIEW_H)
	view.bob(2)
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# The mounts are a CHILD of the view, so they inherit its rect and every
	# position they draw is in the view's own coordinates — which is what makes
	# ShipView.canvas_to_local the only place the sprite's bob, magnification
	# and centring are reasoned about.
	_mountpts = MountPoints.new()
	_mountpts.attach(view)
	_mountpts.dropped.connect(_on_mount_drop)
	view.add_child(_mountpts)
	_view = view
	# CENTRED ON THE PANEL, not on the column and not on the canvas.
	#
	# Two separate reasons the ship was not in the middle, and neither was the
	# one it looked like. It lives in the column the flag leaves, so it starts
	# half a flag right of the panel's centre; and a hull sits right of the
	# middle of its OWN canvas, because the canvas carries the exhaust plume's
	# clearance on one side only.
	#
	# A pad either side, and `_centre_ship` puts the number on the left one.
	var vwrap := HBoxContainer.new()
	vwrap.add_theme_constant_override("separation", 0)
	vwrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# The LEFT pad is the one that carries the number, and the right one only
	# soaks up whatever is over. A minimum on the left is a position; a minimum
	# on the right is a position too, but only while it is the larger of the
	# two, and which of them that is changes with the hull.
	_padl = Control.new()
	_padl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vwrap.add_child(_padl)
	vwrap.add_child(view)
	var padr := Control.new()
	padr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	padr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vwrap.add_child(padr)
	shiprow.add_child(vwrap)
	names.add_child(shiprow)
	left.add_child(header)

	# THE HOLD SITS BESIDE THE WHOLE TEXT COLUMN, not beside one block of it.
	#
	# It was paired with the ATTRIBUTES row alone for two passes, which put the
	# two headings on one line — correct, and kept — but also put the hold IN
	# the column's vertical flow. So HARDPOINTS started below the deepest thing
	# above it, and the deepest thing was the grid rather than the attributes:
	# the gap over HARDPOINTS was being measured off the hold's bottom edge,
	# 30px lower than the numbers it looked like it was spaced from.
	#
	# Out of the flow, the three text blocks space themselves against each
	# other and the hold hangs alongside. The headings still align, because
	# both columns still start at the same row.
	var midrow := HBoxContainer.new()
	midrow.add_theme_constant_override("separation", 14)
	midrow.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# ATTRIBUTES AND HARDPOINTS, with equal space above and below the second.
	# That is what centres HARDPOINTS between the numbers and the abilities: the
	# gap over it and the gap under it are the same object with the same weight,
	# so it stays centred when a hull with more mounts makes its block taller.
	#
	# The MANUFACTURER ABILITIES block is deliberately NOT in here, and that is
	# a horizontal argument rather than a vertical one. Its rows run the width of
	# the panel, so inside this column it — not STATS_W — set the column's width,
	# and the hold got shoved 240px right of where it was pinned. Below the row
	# it can be as wide as it likes.
	var textcol := VBoxContainer.new()
	textcol.add_theme_constant_override("separation", 2)
	# FIXED, not expanding. See STATS_W — this is what pins the hold's top-left
	# corner so it grows down and right.
	textcol.custom_minimum_size = Vector2(STATS_W, 0)
	textcol.size_flags_vertical = Control.SIZE_EXPAND_FILL

	textcol.add_child(UITheme.body("ATTRIBUTES", UITheme.COLD, UITheme.FS_SMALL))
	_attrs = AttrBlock.new()
	textcol.add_child(_attrs)

	# The same block the chassis select shows, on the screen where it is
	# ACTIONABLE. There it answers "what would flying this cost me" before you
	# commit; here it answers "what have I got left", which is the question you
	# are asking on every drop — and it was the one screen in the game where
	# slot pressure was invisible while you were spending it.
	textcol.add_child(_spread())
	textcol.add_child(UITheme.body("HARDPOINTS", UITheme.COLD, UITheme.FS_SMALL))
	_mounts = VBoxContainer.new()
	_mounts.add_theme_constant_override("separation", 2)
	textcol.add_child(_mounts)

	_hand = UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)
	textcol.add_child(_hand)

	textcol.add_child(_spread())
	midrow.add_child(textcol)

	var holdcol := VBoxContainer.new()
	holdcol.add_theme_constant_override("separation", 2)
	holdcol.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_hold = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	holdcol.add_child(_hold)
	# A heading wants air under it. Every other block on this panel gets it from
	# the gap between a label and the first ROW of what it labels; the hold's
	# first row is a hard-edged plate that butts straight up under the text
	# without one.
	var hgap := Control.new()
	hgap.custom_minimum_size = Vector2(0, LABEL_AIR)
	hgap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holdcol.add_child(hgap)
	_storage = HoldGrid.new()
	_storage.dropped.connect(_on_hold_drop)
	holdcol.add_child(_storage)
	midrow.add_child(holdcol)

	left.add_child(midrow)

	# The abilities go here, not on the chassis select's terms. There they
	# answer "what would flying this house give me"; here they answer "how close
	# am I now", and the answer changes every time you drop a part into a mount
	# on the other half of this screen. Under the attributes because it is the
	# same column of facts about the ship — what it is, then what it unlocks.
	# NO SPREAD HERE. The row above is the only expanding child of this
	# column, so a second one halved the space it had to place HARDPOINTS in
	# and dropped the gap over it to 10px against 33 below — the exact
	# lopsidedness this pass set out to remove.
	left.add_child(UITheme.body("MANUFACTURER ABILITIES", UITheme.COLD, UITheme.FS_SMALL))
	_abilities = VBoxContainer.new()
	_abilities.add_theme_constant_override("separation", 1)
	left.add_child(_abilities)
	var foot := Control.new()
	foot.custom_minimum_size = Vector2(0, LABEL_AIR)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(foot)

	var lwrap := Widgets.panel_with(left)
	# FIXED, and not expanding. Everything about where the ship sits is measured
	# off this panel's middle, so a panel whose width depends on what is in it
	# means the target moves whenever the contents do — which is how centring
	# the ship turned into a settling loop you could watch happen.
	lwrap.size_flags_horizontal = Control.SIZE_FILL
	lwrap.custom_minimum_size = Vector2(PANEL_W, 0)
	_panel = lwrap
	body.add_child(lwrap)

	# --- right: the parts, and where they go
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var rgap := Control.new()
	rgap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rgap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(rgap)

	# EXPAND_FILL on the PANEL, not on the column inside it. Setting it on the
	# inner VBox does nothing useful — the wrapper is the child the HBox is
	# sizing, so the panel stayed at its content width and left seven hundred
	# pixels of the screen empty to its right.
	var rwrap := Widgets.panel_with(right)
	rwrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(rwrap)

## Where the ship's own pad has to be for its middle to be the panel's middle.
##
## ARITHMETIC, on the first frame, because the alternative was watching it
## happen. This measured and corrected itself over several frames instead, and
## converged — but the frames it spent converging are frames that get drawn, so
## opening the screen jumped the ship sideways every time. A closed form is only
## possible because PANEL_W is fixed; while the panel could grow to fit the ship
## the two chased each other and nothing closed.
##
## Three terms, all of them things pushing the ship RIGHT of the middle:
## the flag it sits beside, half the width of the view, and how far the hull
## sits from the middle of its own canvas — which is not zero, because the
## canvas carries the exhaust plume's clearance on one side only.
func _centre_ship() -> void:
	if _padl == null or _view == null:
		return
	_padl.custom_minimum_size = Vector2(maxf(0.0,
		(PANEL_W - PANEL_PAD * 2.0) * 0.5
		- (ChassisSelect.Banner.UNITS_W * ChassisSelect.Banner.S + HEADER_SEP)
		- _view.canvas_width() * 0.5
		- _view.ship_offset_x()), 0)

## R TURNS A PART. Whichever one you are holding, or the one under the cursor.
##
## Unhandled rather than a shortcut on a focused control, because neither of the
## two things it acts on can hold focus: a drag preview is owned by the viewport
## and a plate in the hold is something you are pointing at, not something you
## have clicked. The key belongs to the screen, which is the only thing that can
## see both.
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.keycode != KEY_R:
		return
	if _turn_carried() or _turn_in_hold(_storage.get_global_mouse_position()):
		get_viewport().set_input_as_handled()


## Turn what is being dragged. The record and the thing under the cursor both.
func _turn_carried() -> bool:
	var d: Variant = get_viewport().gui_get_drag_data()
	if typeof(d) != TYPE_DICTIONARY or not (d as Dictionary).has("module"):
		return false
	var m: ModuleData = (d as Dictionary).module
	if m == null:
		return false
	m.turned = not m.turned
	if ModuleIcon.carried != null and is_instance_valid(ModuleIcon.carried):
		ModuleIcon.carried.fit_footprint()
		ModuleIcon.carried.spin()
	return true


## Turn a part already sitting in the hold, in place if it will still fit.
##
## The whole move is a take-out-and-put-back, so it has to be able to FAIL
## cleanly: a 1x3 lance in a hold with no three-wide gap has nowhere to go
## turned, and the part must end up exactly where it started rather than in the
## first hole the repacker could find for it.
## `at` is in screen coordinates and defaults to the cursor at the call site.
## Taking it as an argument rather than reading the mouse in here is what makes
## it reachable from `-- fittest`: pushed input events start a drag but never
## move the OS cursor, so a hover this function looked up itself could only ever
## be whatever the physical mouse happened to be sitting on.
func _turn_in_hold(at: Vector2) -> bool:
	if _storage == null:
		return false
	var icon := _storage.icon_at(at)
	if icon == null or icon.module == null:
		return false
	var m := icon.module
	if m.footprint().x == m.footprint().y:
		# Square. Turning it is a no-op, and playing the animation for one would
		# say something happened that did not.
		return true
	var was := m.hold_at
	Run.take_from_hold(m)
	m.turned = not m.turned
	if not Run.place_in_hold(m, was) and not Run.place_in_hold(m):
		m.turned = not m.turned
		Run.place_in_hold(m, was)
		Run.log_line("No room to turn %s." % m.name, &"them")
		return true
	_storage.refresh()
	var now := _storage.icon_at(at)
	if now != null:
		now.spin()
	return true


func _refresh() -> void:
	if Run.hull == null:
		return
	# The hull changed, so its canvas width and its offset inside that canvas
	# may have too.
	_centre_ship()
	var man := Run.hull.manufacturer
	var maker: ManufacturerData = DB.manufacturers.get(man)
	var accent := maker.colour if maker != null else UITheme.CHILL
	_banner.man = man
	_banner.mark = accent
	_banner.field = maker.field if maker != null else UITheme.PANEL
	_banner.queue_redraw()
	_name.text = Run.hull.name.to_upper()
	_maker.text = maker.name.to_upper() if maker != null else "UNBRANDED SALVAGE"
	_maker.add_theme_color_override("font_color", accent)
	_class.text = "%s CHASSIS · %s TIER" % [
		HullData.weight_name(Run.hull.weight).to_upper(), Run.hull.tier_letter()]
	_attrs.setup(Run.attributes(), accent)
	_refresh_mounts()
	_hand.text = "%d cards a turn · %d in the deck" % [Run.hand_size(), Run.deck_size()]

	# Rebuilt every refresh, because the unlock state is the point: fitting a
	# third Korvan part has to light the 3+ row the moment it lands.
	Widgets.clear(_abilities)
	for row in Widgets.ability_rows(man, Run.hull.perk_id, Run.manufacturer_count(man)):
		_abilities.add_child(row)

	# Other allegiances go under the hull's own, and only when you have one. A
	# Korvan ship carrying two Solari parts is two from a second set bonus, and
	# this is now the only place on the screen that says so.
	var others := Widgets.other_maker_rows(man)
	if not others.is_empty():
		_abilities.add_child(UITheme.hsep())
		for row2 in others:
			_abilities.add_child(row2)

	# --- the hardpoints are ON THE SHIP now, drawn over the view on the left.
	# What used to be a rack of squares here is the HARDPOINTS tally under the
	# attributes; what a rack could never say is where a mount actually is.
	if _mountpts != null:
		_mountpts.refresh()

	_storage.refresh()
	# Cells, not parts. "6 of 12" counted parts against a capacity in parts, and
	# neither half of that survives a grid: the hold holds as many things as
	# their shapes allow, so the honest number is how much ROOM is gone.
	_hold.text = "STORAGE — %d of %d cells" % [Run.cargo_used(), Run.cargo_slots()]

## The hardpoint tally, mirroring the chassis select's.
##
## Pads reserve to the same ceiling that screen uses, so the two read as one
## block seen twice rather than as two designs — and the figures line up in a
## column instead of tracking the pad count.
## One share of whatever vertical is left over.
##
## Every one of these has the same expand weight, so N of them divide the slack
## into N equal parts. That is the whole mechanism behind "evenly distributed":
## the column does the arithmetic, and adding a block later does not mean
## re-tuning a set of hand-picked gaps.
func _spread(share: float = 1.0) -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.size_flags_stretch_ratio = share
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _refresh_mounts() -> void:
	Widgets.clear(_mounts)
	for s in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var label := UITheme.body(ModuleData.slot_name(s).to_upper(),
			UITheme.COLD, UITheme.FS_SMALL)
		label.custom_minimum_size = Vector2(46, 0)
		row.add_child(label)
		var pads := ChassisSelect.SlotPads.new()
		pads.setup(Run.slots_used(s), Run.slots_for(s), ChassisSelect._mount_ceiling())
		row.add_child(pads)
		row.add_child(UITheme.body("%d/%d" % [Run.slots_used(s), Run.slots_for(s)],
			UITheme.CHILL, UITheme.FS_SMALL))
		_mounts.add_child(row)

## A part dropped onto a mount ON THE HULL.
##
## The mount is a PLACE, so `index` is carried through to the module rather than
## derived from the order of `installed` — that was the bug the stored `mount`
## fixed and it would come straight back if this appended instead.
func _on_mount_drop(payload: Dictionary, slot: ModuleData.Slot, index: int) -> void:
	var m: ModuleData = payload.get("module")
	if m == null or m.slot != slot:
		return
	var resident := Run.module_at(slot, index)
	if resident == m:
		return

	# Two fitted parts trading mounts EXCHANGE places rather than sending one to
	# the hold — the same rule the rack had, and it matters more here, where the
	# mounts are visibly different positions on the ship.
	if resident != null and Run.installed.has(m):
		var there := m.mount
		m.mount = index
		resident.mount = there
		Sig.ship_changed.emit()
		Run.log_line("Moved %s." % m.name, &"sys")
		_refresh()
		return

	# The resident has nowhere to go but the hold, and if it will not fit there
	# the move is refused BEFORE anything has been taken off the ship.
	if resident != null and not Run.has_room_for(resident):
		Run.log_line("No room in the hold for %s." % resident.name, &"them")
		return

	var was_at := m.hold_at
	if Run.cargo.has(m):
		Run.take_from_hold(m)
	if resident != null:
		Run.installed.erase(resident)
		resident.mount = -1
		if not Run.place_in_hold(resident):
			# Cannot happen — has_room_for said yes a moment ago and nothing has
			# taken cells since. Put everything back rather than trust that.
			resident.mount = index
			Run.installed.append(resident)
			if was_at.x >= 0:
				Run.place_in_hold(m, was_at)
			Run.log_line("No room in the hold for %s." % resident.name, &"them")
			return
	Run.installed.erase(m)
	m.mount = index
	Run.installed.append(m)
	Sig.ship_changed.emit()
	Run.log_line("Fitted %s." % m.name, &"good")
	_refresh()

## The only place `installed` and `cargo` move.
##
## Written as "take it out of wherever it was, then put it where it landed",
## because every case is that: a swap is the same two steps with the resident
## displaced first. Special-casing storage-to-hardpoint and hardpoint-to-storage
## separately is how you end up with a fourth path nobody thought about that
## duplicates a module.
## Would every one of these fit at once?
##
## Asked by placing them for real and rolling back, because "do N parts fit"
## is not a sum: two 1x3 guns need two separate runs of three, and free-cell
## arithmetic says yes to a hold that cannot hold either of them.
## A part dropped onto a CELL of the hold.
##
## Separate from _on_mount_drop because the two answer different questions. A
## hardpoint asks "does this slot type match"; the hold asks "does this shape
## fit here", and the cell it fits at is information a mount has no use for.
func _on_hold_drop(payload: Dictionary, at: Vector2i) -> void:
	var m: ModuleData = payload.get("module")
	if m == null:
		return
	var was_at := m.hold_at
	var from_ship := Run.installed.has(m)
	if Run.cargo.has(m):
		Run.take_from_hold(m)
	if not Run.place_in_hold(m, at):
		# Put it back exactly where it was. A refused move must cost nothing —
		# the alternative is a part that vanishes because the arithmetic said no
		# after it had already been lifted.
		if not from_ship and was_at.x >= 0:
			Run.place_in_hold(m, was_at)
		return
	if from_ship:
		Run.installed.erase(m)
		m.mount = -1
		Run.log_line("Stowed %s." % m.name, &"sys")
	Sig.ship_changed.emit()
	_refresh()