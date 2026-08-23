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
## The ship panel's height, off the SPEC rather than off whatever hull happens to
## exist: the largest class is 125x50 at 2x the box, so 100 rows plus the bob.
##
## 150, and it is a BUDGET rather than a size. The masthead is SHRINK_BEGIN and
## the workbench is EXPAND_FILL, so every row given to the ship is a row taken
## off the panel below. Measured with `-- shipshot`, on the heavy, which is the
## tight case — its hold is 6x5 against the light's 4x3:
##
##     view    masthead   workbench   the heavy
##     104        175         311     what it actually was, see below
##     150        221         265     here. 19 rows clear under the abilities
##     160        231         262     also fits
##     165        236         257     still fits, nothing left over
##     200        271         222     abilities clipped off the panel
##
## 104 is in that table because it is where this screen SAT, not where it was
## set. ShipView._resize_canvas ignored the height it was handed unless the view
## was magnified, so at 1x the panel silently took the canvas's own depth and
## this constant did nothing at all. Honouring it is the whole of the extra room:
## the number here is unchanged and the panel is 46 rows deeper than it was.
##
## The panel bottom does not move as this grows. Two equal expanding spacers in
## `textcol` carry all the slack, so what shrinks is the air between ATTRIBUTES,
## HARDPOINTS and MANUFACTURER ABILITIES — and it shrinks EQUALLY, which is the
## property worth keeping. At 150 those two gaps are 20 rows each. At 200 they
## are nothing and the abilities fall off the panel, which is the failure to
## watch for: it does not throw, and it only happens on one of the three weights.
const HULL_VIEW_H := 150

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
## 504, not 524. The right panel takes whatever the left column leaves, and a
## readout NUDGES right on hover — so the row it sits in has to have twenty
## pixels of slack or the far card slides under the screen edge while you are
## reading about it. Taking them from here rather than adding them there,
## because the left column is the one with room: its widest block, the
## manufacturer abilities, wants 470 across.
const PANEL_W := 504

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

## How wide a module readout is in the installed list.
##
## WIDER THAN A CARD, deliberately. At a card's 112 the longest maker line
## wrapped to two rows on Korvan parts and one on unbranded ones, so the boxes
## were the same width and different HEIGHTS — which is the same raggedness
## moved to the other axis. 150 fits "KORVAN HEAVY WORKS" on one line.
const READOUT_W := 150.0

## How far a readout slides right while it is being pointed at.
##
## Animated through a MarginContainer rather than by setting `position`: the
## readout lives in an HBox, and a container overwrites a child's position on
## the next layout pass. A margin is a thing the container itself honours.
const NUDGE := 7.0

## THE PART CURRENTLY IN THE AIR, and where it came off.
##
## A part dragged off the hull leaves the ship at the moment it is picked up,
## which means that between the grab and the drop it belongs to NOTHING — not
## `installed`, not `cargo`. That is the state this remembers, and `_on_release`
## is what guarantees it cannot outlive the drag: a drag abandoned over the star
## chart would otherwise delete the module.
var _lifted: ModuleData = null
var _lifted_mount: int = -1


## The pad that places the ship, and the panel it is placed against.
var _padl: Control
var _panel: Control
var _storage: HoldGrid
var _attrs: AttrBlock
var _mounts: VBoxContainer
var _reactor: Label
var _mountpts: MountPoints
var _view: ShipView
var _banner: ChassisSelect.Banner
var _name: Label
var _maker: Label
var _class: Label
var _hand: Label
var _hold: Label
var _abilities: VBoxContainer
var _fithead: Label
var _fitted: VBoxContainer

## The clipping box the ship is drawn inside, and where it sits in it.
var _clip: Control
var _zoomed: bool = false
var _pan: Vector2 = Vector2.ZERO
var _panning: bool = false
var _zoombtn: Button

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
	# TWO PANELS, ONE ABOVE THE OTHER. What the ship IS — its flag, its name and
	# the hull itself — is a masthead, and the numbers under it are a workbench.
	# One box around both made the ship look like the first row of a table.
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 2)

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
	var clsrow := HBoxContainer.new()
	clsrow.add_theme_constant_override("separation", 8)
	_class = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	clsrow.add_child(_class)
	# Beside the class line rather than over the ship: anything drawn on the
	# hull is a hardpoint, and a button there would read as one.
	_zoombtn = Button.new()
	_zoombtn.text = "ZOOM"
	_zoombtn.focus_mode = Control.FOCUS_NONE
	_zoombtn.tooltip_text = "Z - double the ship, then drag it about"
	_zoombtn.pressed.connect(func(): _set_zoom(not _zoomed))
	clsrow.add_child(_zoombtn)
	names.add_child(clsrow)
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
	# 1x, and the height sized off the TALLEST hull rather than off the one that
	# used to be the only one.
	#
	# 2x was set when every hull was procedural at 240x120 and the one real
	# sprite was 188x88. The shipped hulls are 150x60, 200x80 and 248x100, so 2x
	# drew a 496px ship on a 960px viewport — over half the screen width — and
	# clipped the deepest ones top and bottom. Integer magnification is the art
	# rule and 1x is the only step below 2x, so this is half rather than a nudge;
	# the viewport is itself scaled 2x into a 1920x1080 window, so an art pixel
	# still lands on four real ones and stays crisp.
	view.magnify(1, HULL_VIEW_H)
	view.bob(2)
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# The mounts are a CHILD of the view, so they inherit its rect and every
	# position they draw is in the view's own coordinates — which is what makes
	# ShipView.canvas_to_local the only place the sprite's bob, magnification
	# and centring are reasoned about.
	_mountpts = MountPoints.new()
	_mountpts.attach(view)
	_mountpts.dropped.connect(_on_mount_drop)
	_mountpts.lifted.connect(_on_lift)
	_mountpts.released.connect(_on_release)
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
	# THE CLIP BOX. It is what the layout sizes and centres; the view inside
	# it is free to be bigger and to be dragged about. At 1x the two are the
	# same size and this is invisible, which is what keeps every measurement
	# in `_centre_ship` true -- the box does not change size when zoom does.
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_STOP
	_clip.gui_input.connect(_on_clip_input)
	_clip.add_child(view)
	vwrap.add_child(_clip)
	var padr := Control.new()
	padr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	padr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vwrap.add_child(padr)
	shiprow.add_child(vwrap)
	names.add_child(shiprow)
	top.add_child(header)

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

	# THE SECOND BUDGET, under the first one. Hardpoints answer "is there
	# anywhere to bolt this"; the reactor answers "can I run it" — and a player
	# refused a part needs to be told WHICH of the two said no. Directly beneath
	# the mount rows because it is the same question asked about the same drop.
	_reactor = UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)
	textcol.add_child(_reactor)

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

	var lcol := VBoxContainer.new()
	lcol.add_theme_constant_override("separation", 5)
	# FIXED, and not expanding. Everything about where the ship sits is measured
	# off its panel's middle, so a panel whose width depends on what is in it
	# means the target moves whenever the contents do — which is how centring
	# the ship turned into a settling loop you could watch happen.
	lcol.size_flags_horizontal = Control.SIZE_FILL
	lcol.custom_minimum_size = Vector2(PANEL_W, 0)

	var twrap := Widgets.panel_with(top)
	# SHRINK_BEGIN: the masthead is as deep as the ship in it and no deeper. The
	# leftover belongs to the workbench, which has four blocks to space out.
	twrap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# The ship is centred against THIS panel now, not against the whole column.
	_panel = twrap
	lcol.add_child(twrap)

	var lwrap := Widgets.panel_with(left)
	lwrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lcol.add_child(lwrap)
	body.add_child(lcol)

	# --- right: what is bolted on, and what it puts in the deck
	#
	# THIS PANEL WAS EMPTY. The hold moved to the left column and nothing took
	# its place, so a third of the screen was a lit box with a spacer in it.
	#
	# It answers the question the left panel cannot. The left says what the ship
	# IS — its numbers, its budgets, its silhouette. This says what you have
	# ASSEMBLED: the parts on the hull, and the cards those parts will deal you.
	# A module's cards were previously visible only in a tooltip, one module at a
	# time, which is the wrong shape for the question "what does my deck look
	# like now" — that is a question about all of them at once.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_fithead = UITheme.body("INSTALLED", UITheme.COLD, UITheme.FS_SMALL)
	right.add_child(_fithead)

	# SCROLLED, because this is the one block with no ceiling: a heavy S carries
	# nine mounts and each module brings its own cards. Horizontal scrolling is
	# off — a row is three card-widths and the panel is wider than that, so a
	# sideways bar could only ever mean the window is too small for one row.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_fitted = VBoxContainer.new()
	_fitted.add_theme_constant_override("separation", 8)
	_fitted.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_fitted)
	right.add_child(scroll)

	# EXPAND_FILL on the PANEL, not on the column inside it. Setting it on the
	# inner VBox does nothing useful — the wrapper is the child the HBox is
	# sizing, so the panel stayed at its content width and left seven hundred
	# pixels of the screen empty to its right.
	var rwrap := Widgets.panel_with(right)
	rwrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(rwrap)

## SUPERSEDED by `_sync_clip`, which places the view inside the window rather
## than padding a row to push it. Kept as a name the rest of the screen calls
## when the hull changes; the arithmetic it used to hold is in `_ship_x`.
func _centre_ship() -> void:
	_sync_clip()

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_Z:
		_set_zoom(not _zoomed)
		get_viewport().set_input_as_handled()
		return
	if k.keycode == KEY_ESCAPE and _zoomed:
		_set_zoom(false)
		get_viewport().set_input_as_handled()
		return
	# F FLIPS WHAT YOU ARE POINTING AT, on the hull only. R turns a part in
	# the hold and F mirrors one on the ship: two verbs, two places, and
	# neither reaches into the other's.
	if k.keycode == KEY_F:
		if _flip_pointed():
			get_viewport().set_input_as_handled()
		return
	if k.keycode != KEY_R:
		return
	if _turn_carried() or _turn_in_hold(_storage.get_global_mouse_position()):
		get_viewport().set_input_as_handled()

## ZOOM, IN PLACE. The ship doubles and the panel does not.
##
## The panel cannot grow: the left column is a fixed 524px because everything
## about where the ship sits is measured off its middle, and `_centre_ship`
## closes in one frame only while that width cannot move. So the box stays the
## size it was at 1x, a doubled ship is simply bigger than its window, and that
## is why this comes with a drag.
##
## MountPoints goes to PASS while zoomed. It is STOP normally and covers the
## whole hull, so with it stopping events the box underneath never saw a press
## and nothing could be dragged. PASS still delivers its hover and still leaves
## it a drop target -- IGNORE is the filter that would break those -- and the
## event carries on to the box behind it.
func _set_zoom(on: bool) -> void:
	if _view == null or _clip == null:
		return
	_zoomed = on
	if not on:
		_pan = Vector2.ZERO
	_view.magnify(2 if on else 1, HULL_VIEW_H)
	if _mountpts != null:
		_mountpts.mouse_filter = (Control.MOUSE_FILTER_PASS if on
			else Control.MOUSE_FILTER_STOP)
	if _zoombtn != null:
		_zoombtn.text = "RESET" if on else "ZOOM"
	_sync_clip()

## How much width the ship's row actually has, inside the panel and beside the
## flag. The window onto the ship is this wide at every zoom level.
func _row_width() -> float:
	return ((PANEL_W - PANEL_PAD * 2.0)
		- (ChassisSelect.Banner.UNITS_W * ChassisSelect.Banner.S + HEADER_SEP))

## How far a MODULE may stick out past the hull canvas.
##
## A gun is drawn on a mount and its barrel runs off the end of the sprite it is
## bolted to, so a window sized to the canvas cuts the front off the longest one.
## The canvas is the hull's extent, never the ship's.
const MOUNT_BLEED := 72.0

## Where the ship's left edge goes so its middle is the PANEL's middle.
##
## Same arithmetic that used to set the left pad, applied to the view's position
## inside the box instead. Three terms, all of them things pushing the ship right
## of the middle: the flag it sits beside, half the width of the view, and how
## far the hull sits from the middle of its own canvas -- which is not zero,
## because the canvas carries the exhaust plume's clearance on one side only.
func _ship_x() -> float:
	if _view == null:
		return 0.0
	return ((PANEL_W - PANEL_PAD * 2.0) * 0.5
		- (ChassisSelect.Banner.UNITS_W * ChassisSelect.Banner.S + HEADER_SEP)
		- _view.canvas_width() * 0.5
		- _view.ship_offset_x())

## Size the window onto the ship, and place the ship in it.
##
## THE WINDOW IS THE WHOLE ROW, at 1x as well as zoomed. It was the canvas width
## at 1x, which put an invisible edge exactly on the hull's bounding box and cut
## the muzzle off the longest gun -- the hull ends there, the SHIP does not.
func _sync_clip() -> void:
	if _clip == null or _view == null:
		return
	var box := Vector2(maxf(_row_width(), 1.0), float(HULL_VIEW_H))
	_clip.custom_minimum_size = box
	_clip.size = box
	# The box fills the row, so there is nothing left for the pad to do.
	if _padl != null:
		_padl.custom_minimum_size = Vector2.ZERO
	_view.size = Vector2(_view.canvas_width(), _view.canvas_height())
	_view.position = (Vector2(_ship_x(), (box.y - _view.size.y) * 0.5)
		+ _pan).floor()
	# THE MOUNTS HAVE TO BE TOLD. Every marker and fitted part is placed through
	# ShipView.canvas_to_local, which reads the magnification and the view's rect
	# -- both of which just changed. Without this they keep last frame's positions
	# and appear to float off the hull until something else repaints them.
	if _mountpts != null:
		_mountpts.refresh()
		# And again once layout has settled: the call above runs before the
		# container has resized its children, so it places against the OLD rect.
		_mountpts.refresh.call_deferred()

## Drag to pan, but only while zoomed and only when nothing is being carried.
##
## `gui_is_dragging` is the guard that matters: a module lifted off a mount is a
## live Godot drag and its motion still arrives here. Without it, taking a gun
## off the hull also slid the ship out from under the cursor.
func _on_clip_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_panning = mb.pressed and not get_viewport().gui_is_dragging()
		return
	var mm := event as InputEventMouseMotion
	if mm == null or not _panning:
		return
	if get_viewport().gui_is_dragging():
		_panning = false
		return
	_pan += mm.relative
	# Far enough to bring an overhanging gun into the window, and no
	# further. Measured off the SHIP's extent rather than the box's, so it
	# still allows movement at 1x where the hull is narrower than the row.
	var slack := (_view.size - _clip.size) * 0.5
	slack.x = maxf(slack.x, 0.0) + MOUNT_BLEED
	slack.y = maxf(slack.y, 0.0) + MOUNT_BLEED * 0.5
	_pan.x = clampf(_pan.x, -slack.x, slack.x)
	_pan.y = clampf(_pan.y, -slack.y, slack.y)
	_view.position = (Vector2(_ship_x(),
		(_clip.size.y - _view.size.y) * 0.5) + _pan).floor()
	if _mountpts != null:
		_mountpts.refresh()

## Mirror the fitted part under the cursor, top to bottom.
##
## Drawing only, so nothing is revalidated: a flipped gun holds the same
## mount, costs the same energy and deals the same damage. It is which way
## up the object READS, and a ventral rack needs the other way up.
func _flip_pointed() -> bool:
	if _mountpts == null:
		return false
	var m := _mountpts.part_under(_mountpts.get_local_mouse_position())
	if m == null:
		return false
	m.flipped = not m.flipped
	_mountpts.refresh()
	return true

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
	# may have too -- and the clip box is sized off the canvas, so it has to
	# be re-fitted before anything is centred against it.
	_sync_clip()
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
	var draw := Run.power_draw()
	var cap := Run.power_cap()
	_reactor.text = "REACTOR — %d of %d cells · %d energy" % [draw, cap, Run.reactor()]
	# EMBER AT THE CEILING, and only there. A bar that changes colour on the way
	# up teaches a player to read the colour instead of the number; this one
	# only ever means "the next part costs you a part".
	_reactor.add_theme_color_override("font_color",
		UITheme.EMBER if draw >= cap else UITheme.CHILL)
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

	_refresh_loadout()

## What is bolted on, and every card it will deal you.
##
## Grouped by slot rather than listed flat, because that is how the ship is
## budgeted: the tally on the left says two of three weapons are filled, and
## this is the row that says WHICH two. A flat list makes you count.
##
## Cards at hand scale, which is the scale they are played at. Inspect scale
## exists and is exactly 2x, but a card you are reading in a panel is the same
## card you will read in a hand, and showing it larger here would teach a size
## that never appears in combat.
## Point the hull at a part in the list, so reading about it shows you where
## it is. The reverse direction already existed — hovering the ship outlines
## everything on it — and this closes the loop from the other side.
func _focus_part(m: ModuleData, slot: MarginContainer = null,
		on: bool = false) -> void:
	if _mountpts != null:
		_mountpts.focus(m)
	if slot == null:
		return
	# One tween per row, killed before a new one starts: moving the mouse
	# along the column fires enter and exit faster than a tween finishes,
	# and two live tweens on one margin fight over it.
	var old: Tween = slot.get_meta(&"nudge", null) as Tween
	if old != null and old.is_valid():
		old.kill()
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(v: float) -> void:
		slot.add_theme_constant_override("margin_left", int(round(v))),
		float(slot.get_theme_constant("margin_left")),
		NUDGE if on else 0.0, 0.12)
	slot.set_meta(&"nudge", tw)

func _refresh_loadout() -> void:
	if _fitted == null:
		return
	Widgets.clear(_fitted)

	var fitted := 0
	var mounts := 0
	var cards := 0
	for s in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]:
		mounts += Run.slots_for(s)
		var mine: Array[ModuleData] = []
		for m in Run.installed:
			if m.slot == s:
				mine.append(m)
		if mine.is_empty():
			continue
		_fitted.add_child(UITheme.body(
			"%s — %d of %d" % [ModuleData.slot_name(s).to_upper(),
				mine.size(), Run.slots_for(s)],
			UITheme.COLD, UITheme.FS_SMALL))
		for m in mine:
			fitted += 1
			# MODULE FIRST, THEN ITS CARDS. The part is the thing you fitted
			# and the cards are what it gives you, so the row reads in the
			# order the decision was made — and every row starts with the
			# maker's colour bar down its left edge, which turns the column
			# into something you can scan by house.
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			# A CARD'S WIDTH exactly, so the rows line up into a column. Left to
			# itself the box grows to its longest line and no two modules agree.
			var ro := Widgets.module_readout(m, READOUT_W)
			# STOP, because module_readout hands back an IGNORE panel — it is
			# built for a tooltip, where eating the mouse would count as
			# leaving the thing being pointed at. Here it IS the thing.
			ro.mouse_filter = Control.MOUSE_FILTER_STOP
			var slot := MarginContainer.new()
			slot.add_theme_constant_override("margin_left", 0)
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(ro)
			ro.mouse_entered.connect(_focus_part.bind(m, slot, true))
			ro.mouse_exited.connect(_focus_part.bind(null, slot, false))
			row.add_child(slot)
			for c in m.resolved_cards():
				cards += 1
				var cv := CardView.new()
				# TRUE, and it is not a claim about affordability. `playable`
				# drives `modulate.a` — false renders at 34% and the whole panel
				# came out looking disabled. There is no energy pool on a refit
				# screen for a card to be unaffordable against.
				cv.setup(c, true, 1)
				# IGNORE. These are a readout, not a hand: a card that eats the
				# mouse here would swallow the scroll wheel over half the panel.
				cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(cv)
			_fitted.add_child(row)

	if fitted == 0:
		_fitted.add_child(UITheme.body("Nothing bolted on yet.",
			UITheme.COLD, UITheme.FS_SMALL))
	_fithead.text = "INSTALLED — %d of %d mounts · %d card%s" % [
		fitted, mounts, cards, "" if cards == 1 else "s"]

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
## Off the ship, into the hand.
func _on_lift(m: ModuleData) -> void:
	if m == null or not Run.installed.has(m):
		return
	_lifted = m
	_lifted_mount = m.mount
	Run.installed.erase(m)
	m.mount = -1
	Sig.ship_changed.emit()
	_refresh()


## The drag ended. If what was lifted never landed, put it back exactly where it
## was — the same rule a refused move in the hold follows, for the same reason:
## picking a thing up is not a decision to get rid of it.
func _on_release() -> void:
	var m := _lifted
	_lifted = null
	if m == null or Run.installed.has(m) or Run.cargo.has(m):
		return
	m.mount = _lifted_mount
	Run.installed.append(m)
	Sig.ship_changed.emit()
	_refresh()


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
	#
	# `m == _lifted` is the same case: a part dragged off the hull is off the
	# ship while you carry it, so `installed.has(m)` is false for exactly the
	# move this branch exists for. Without it, sliding a gun from one hardpoint
	# to an occupied one sent the resident to the hold instead of trading.
	var was_fitted := Run.installed.has(m) or m == _lifted
	if resident != null and was_fitted:
		var there := _lifted_mount if m == _lifted else m.mount
		m.mount = index
		resident.mount = there
		if m == _lifted:
			Run.installed.append(m)
			_lifted = null
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
	_lifted = null
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
	# `_lifted` counts as from the ship: it left `installed` when you picked it
	# up, and this is the branch that decides whether to say so in the log.
	var from_ship := Run.installed.has(m) or m == _lifted
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
		_lifted = null
		Run.log_line("Stowed %s." % m.name, &"sys")
	Sig.ship_changed.emit()
	_refresh()