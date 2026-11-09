class_name ShipScreen
extends Control

## Refit workbench. No melter here: drag-to-destroy made the one irreversible verb too
## easy.
## Why: docs/why/ShipScreen.md#refit-workbench

## Superseded by HoldGrid. Four columns suit capacities 8/12/16 and fit the 944px viewport.
## `HULL_VIEW_H` is a height budget measured with `-- shipshot`, not a size.
## Why: docs/why/ShipScreen.md#hold-and-panel-sizing
const HULL_VIEW_H := 150

## Mount markers draw above the hull's top edge, so this clears them from the class line.
## Why: docs/why/ShipScreen.md#hull-view-spacing
const HEAD_GAP := 0

## Pins the hold's top-left so it grows down and right, not left into the attributes.
## Why: docs/why/ShipScreen.md#hold-placement
const STATS_W := 220

## Measured gaps and widths: the left panel is fixed so the ship centring does not drift.
## Hover nudge needs 20px of slack on the right panel, so 504 not 524.
## Why: docs/why/ShipScreen.md#panel-widths
const PANEL_W := 504

## What Widgets.panel_with insets its child by, on each side.
const PANEL_PAD := 12

const HEADER_SEP := 10

const LABEL_AIR := 3

## No explicit gap under the ship: the flag already ends 8px above ATTRIBUTES. A spacer
## made 16.
## Why: docs/why/ShipScreen.md#panel-widths

const STORAGE_COLS := 4

## Wider than a card so manufacturer lines do not wrap and make boxes uneven in height.
## Why: docs/why/ShipScreen.md#module-readouts
const READOUT_W := 150.0

## Animated through a MarginContainer: a container overwrites a child's `position` on
## layout.
## Why: docs/why/ShipScreen.md#module-readouts
const NUDGE := 7.0

## Between grab and drop the part is in neither `installed` nor `cargo`; `_on_release` must
## restore it.
## Why: docs/why/ShipScreen.md#lifted-part
var _lifted: ModuleData = null
var _lifted_mount: int = -1


## The pad that places the ship, and the panel it is placed against.
var _padl: Control
var _panel: Control
var _storage: HoldGrid
## The dock, and the line above it. Both hidden unless `Run.pad` has something
## on it, which outside the visit where you bought a ship is never.
var _dock: PadStrip
var _dockhead: Label
var _dockbox: ScrollContainer

## Two dock rows: that is all the room left under the hold on a heavy in a 540px window.
const DOCK_ROWS := 2
var _attrs: AttrBlock
var _mounts: VBoxContainer
var _reactor: Label
var _mountpts: MountPoints
var _view: ShipView
var _banner: ChassisSelect.Banner
var _name: Label
var _namebtn: Button
## One field: freeing the shade frees the whole prompt card.
var _rename: ColorRect
## How long a ship's name may be. Longer than this and the masthead wraps.
const NAME_MAX := 24
var _manufacturer: Label
var _class: Label
var _hand: Label
var _hold: Label
## An overlay, not a column: a new sibling would narrow the ship's window and shift the
## ship.
var _perkbox: PerkBox
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
	# Two panels: the masthead says what the ship is, the workbench holds the numbers. One box
	# around both made the ship look like the first row of a table.
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 2)

	var left := VBoxContainer.new()
	# Separation 2 not 4: this column has ten blocks and each pixel costs ten of height.
	left.add_theme_constant_override("separation", 2)

	# The flag hangs the full depth of the ship: it names whose yard built it, and a short
	# badge reads as a bullet.
	# Why: docs/why/ShipScreen.md#masthead-flag
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", HEADER_SEP)
	_banner = ChassisSelect.Banner.new()
	# Minimum is the authored flag depth so the hem is never cut off; FILL takes it to the
	# ship's bottom.
	_banner.custom_minimum_size = ChassisSelect.Banner.S * Vector2(
		ChassisSelect.Banner.UNITS_W, ChassisSelect.Banner.UNITS_H)
	_banner.size_flags_vertical = Control.SIZE_FILL
	header.add_child(_banner)

	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 1)
	# Must expand, or the ship's centring pads have nothing to divide and both come out zero.
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Name and pencil on their own row so the button sits against the text, not at the column
	# edge.
	# Why: docs/why/ShipScreen.md#masthead-flag
	var namerow := HBoxContainer.new()
	# FOUR, not six. See NameEdit.PAD_X -- the button carries its own air, and
	# the two were adding up to a gap wide enough to read as a separator.
	namerow.add_theme_constant_override("separation", 4)
	_name = UITheme.body("", UITheme.ICE, UITheme.FS_HEAD)
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	namerow.add_child(_name)
	_namebtn = NameEdit.new()
	_namebtn.pressed.connect(_open_rename)
	namerow.add_child(_namebtn)
	names.add_child(namerow)
	_manufacturer = UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)
	names.add_child(_manufacturer)
	var clsrow := HBoxContainer.new()
	clsrow.add_theme_constant_override("separation", 8)
	_class = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	clsrow.add_child(_class)
	# Beside the class line rather than over the ship: anything drawn on the
	# hull is a hardpoint, and a button there would read as one.
	_zoombtn = Button.new()
	Widgets.wear_pointer(_zoombtn)
	_zoombtn.text = "ZOOM"
	_zoombtn.focus_mode = Control.FOCUS_NONE
	_zoombtn.tooltip_text = Widgets.tip(
		"Shows the ship at double size, so you can drag it around. Z does the same.")
	_zoombtn.pressed.connect(func(): _set_zoom(not _zoomed))
	clsrow.add_child(_zoombtn)
	names.add_child(clsrow)
	header.add_child(names)

	# Fixed clearance, not a spacer that shares slack: mount markers draw above the hull's top
	# edge.
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, HEAD_GAP)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(gap)

	# Flag spans the ship's depth: it is the one piece saying whose yard built it.
	var shiprow := HBoxContainer.new()
	shiprow.add_theme_constant_override("separation", 8)

	# Doubled and cropped like the chassis select; at 1x the ship was adrift in empty panel.
	var view := ShipView.new()
	# 1x, sized off the tallest hull: 2x drew a 496px ship on a 960px viewport. The window
	# clips.
	# Why: docs/why/ShipScreen.md#hull-view-scale
	view.self_clip = false
	view.magnify(1, HULL_VIEW_H)
	view.bob(2)
	# Heard as well as seen: the idle flame is on screen, so its bed is too.
	view.hums = true
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Mounts are a child of the view so `ShipView.canvas_to_local` is the only place sprite
	# offsets are reasoned about.
	_mountpts = MountPoints.new()
	_mountpts.attach(view)
	_mountpts.dropped.connect(_on_mount_drop)
	_mountpts.lifted.connect(_on_lift)
	_mountpts.released.connect(_on_release)
	view.add_child(_mountpts)
	_view = view
	# Centred on the panel: the flag and the plume clearance both push the hull right of the
	# column's middle.
	# Why: docs/why/ShipScreen.md#ship-centring
	var vwrap := HBoxContainer.new()
	vwrap.add_theme_constant_override("separation", 0)
	vwrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vwrap.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# The left pad carries the number; the right only soaks up the rest, as which is larger
	# varies by hull.
	_padl = Control.new()
	_padl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vwrap.add_child(_padl)
	# The clip box is what layout sizes; the view may grow, so `_centre_ship` measurements
	# hold at any zoom.
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_STOP
	_clip.gui_input.connect(_on_clip_input)
	_clip.add_child(view)
	# The window takes the rest of the row: a computed width left an invisible edge that cut
	# the longest muzzle.
	# Why: docs/why/ShipScreen.md#hull-view-window
	_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Vertical expand too: a pinned height cut 58 rows off a doubled heavy while the panel had
	# room.
	_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vwrap.add_child(_clip)
	shiprow.add_child(vwrap)
	names.add_child(shiprow)
	top.add_child(header)

	# The hold sits beside the whole text column, out of its flow, so HARDPOINTS spacing is
	# not measured off the grid.
	# Why: docs/why/ShipScreen.md#hold-beside-text-column
	var midrow := HBoxContainer.new()
	midrow.add_theme_constant_override("separation", 14)
	midrow.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Equal space above and below HARDPOINTS keeps it centred. The column stays fixed-width:
	# `STATS_W` places the hold.
	# Why: docs/why/ShipScreen.md#text-column
	var textcol := VBoxContainer.new()
	textcol.add_theme_constant_override("separation", 2)
	# FIXED, not expanding. See STATS_W — this is what pins the hold's top-left
	# corner so it grows down and right.
	textcol.custom_minimum_size = Vector2(STATS_W, 0)
	textcol.size_flags_vertical = Control.SIZE_EXPAND_FILL

	textcol.add_child(UITheme.body("ATTRIBUTES", UITheme.COLD, UITheme.FS_SMALL))
	_attrs = AttrBlock.new()
	textcol.add_child(_attrs)

	# Same block the chassis select shows, here where slot pressure is actionable on every
	# drop.
	textcol.add_child(_spread())
	textcol.add_child(UITheme.body("HARDPOINTS", UITheme.COLD, UITheme.FS_SMALL))
	_mounts = VBoxContainer.new()
	_mounts.add_theme_constant_override("separation", 2)
	textcol.add_child(_mounts)

	# Reactor is the second budget: a refused part needs to say which of the two budgets said
	# no.
	_reactor = UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)
	textcol.add_child(_reactor)

	_hand = UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)
	textcol.add_child(_hand)

	textcol.add_child(_spread())
	midrow.add_child(textcol)

	var holdcol := VBoxContainer.new()
	holdcol.add_theme_constant_override("separation", 2)
	holdcol.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# Heading and hatch share a row: under the grid it fell off the bottom on a heavy hull.
	# Why: docs/why/ShipScreen.md#hold-heading-row
	var holdhead := HBoxContainer.new()
	holdhead.add_theme_constant_override("separation", 8)
	_hold = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_hold.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holdhead.add_child(_hold)
	var headgap := Control.new()
	headgap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	headgap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holdhead.add_child(headgap)
	var bin := JettisonBin.new()
	bin.dumped.connect(func(_m: HoldItem) -> void: _refresh())
	holdhead.add_child(bin)
	holdcol.add_child(holdhead)
	# The hold's first row is a hard-edged plate, so the heading needs explicit air under it.
	var hgap := Control.new()
	hgap.custom_minimum_size = Vector2(0, LABEL_AIR)
	hgap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holdcol.add_child(hgap)
	_storage = HoldGrid.new()
	_storage.dropped.connect(_on_hold_drop)
	holdcol.add_child(_storage)

	# --- THE DOCK, UNDER THE HOLD.
	# Under the hold, not beside it: same column count, so a part that will not fit sits above
	# the cells it needs.
	# Why: docs/why/ShipScreen.md#dock-strip
	_dockhead = UITheme.body("", UITheme.LEAVE, UITheme.FS_SMALL)
	holdcol.add_child(_dockhead)
	# --- BOUNDED, AND THEREFORE SCROLLED.
	# Bounded and scrolled: seven stranded parts overran the window. Cell size stays the
	# hold's.
	# Why: docs/why/ShipScreen.md#dock-strip
	var dockbox := ScrollContainer.new()
	dockbox.custom_minimum_size = Vector2(0, DOCK_ROWS * (PadStrip.CELL
		+ PadStrip.GAP) - PadStrip.GAP)
	dockbox.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dock = PadStrip.new()
	dockbox.add_child(_dock)
	_dockbox = dockbox
	holdcol.add_child(dockbox)

	midrow.add_child(holdcol)

	left.add_child(midrow)

	# No manufacturer abilities block, removed on request. Hull perks stay in the masthead
	# corner.
	# Why: docs/why/ShipScreen.md#removed-abilities-block
	var foot := Control.new()
	foot.custom_minimum_size = Vector2(0, LABEL_AIR)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(foot)

	var lcol := VBoxContainer.new()
	lcol.add_theme_constant_override("separation", 5)
	# Fixed width: a panel sized by its contents moves the centring target, which made a
	# visible settling loop.
	lcol.size_flags_horizontal = Control.SIZE_FILL
	lcol.custom_minimum_size = Vector2(PANEL_W, 0)

	var twrap := Widgets.panel_with(top)
	# SHRINK_BEGIN: the masthead is as deep as the ship in it and no deeper. The
	# leftover belongs to the workbench, which has four blocks to space out.
	twrap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# The ship is centred against THIS panel now, not against the whole column.
	_panel = twrap
	lcol.add_child(twrap)

	# Perks sit top right over the masthead: named here, described on hover to save a panel-
	# wide block.
	_perkbox = PerkBox.new()
	_perkbox.add_theme_constant_override("separation", 1)
	# Top level, laid out by hand: a Container stretched the box over the ship and broke part
	# pickup.
	# Why: docs/why/ShipScreen.md#perk-box-top-level
	_perkbox.set_as_top_level(true)
	# PASS, not STOP: the labels inside want hover for their tooltips, but the
	# column between and around them must not eat a drag meant for the ship.
	_perkbox.mouse_filter = Control.MOUSE_FILTER_PASS
	twrap.add_child(_perkbox)
	twrap.resized.connect(_place_perks)
	_perkbox.resized.connect(_place_perks)

	var lwrap := Widgets.panel_with(left)
	lwrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lcol.add_child(lwrap)
	body.add_child(lcol)

	# --- right: what is bolted on, and what it puts in the deck
	# The right panel shows the assembled loadout and its cards, which a tooltip showed one at
	# a time.
	# Why: docs/why/ShipScreen.md#right-panel
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_fithead = UITheme.body("INSTALLED", UITheme.COLD, UITheme.FS_SMALL)
	right.add_child(_fithead)

	# Scrolled vertically only: nine mounts plus each module's cards have no ceiling.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_fitted = VBoxContainer.new()
	_fitted.add_theme_constant_override("separation", 8)
	_fitted.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_fitted)
	right.add_child(scroll)

	# EXPAND_FILL goes on the panel wrapper, not the inner VBox, or it keeps its content
	# width.
	var rwrap := Widgets.panel_with(right)
	rwrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(rwrap)

## Superseded by `_sync_clip`. Kept as a name callers use on hull change.
func _centre_ship() -> void:
	_sync_clip()

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	# The rename shade stops the mouse but not keys, so Z and F would act behind it. Escape is
	# handled here because `_unhandled_key_input` runs after the LineEdit declines.
	# Why: docs/why/ShipScreen.md#rename-prompt-input
	if _rename != null:
		if k.keycode == KEY_ESCAPE:
			_close_rename()
		get_viewport().set_input_as_handled()
		return
	# Z, F and R are bindings (`Keys`); Escape is not.
	if k.is_action_pressed(&"ship_zoom"):
		_set_zoom(not _zoomed)
		get_viewport().set_input_as_handled()
		return
	if k.keycode == KEY_ESCAPE and _zoomed:
		_set_zoom(false)
		get_viewport().set_input_as_handled()
		return
	# F mirrors a part on the ship and R turns one in the hold: two verbs, two places.
	if k.is_action_pressed(&"part_flip"):
		if _flip_pointed():
			get_viewport().set_input_as_handled()
		return
	if not k.is_action_pressed(&"hold_turn"):
		return
	if _turn_carried() or _turn_in_hold(_storage.get_global_mouse_position()):
		get_viewport().set_input_as_handled()

## Zoom keeps the panel size so `_centre_ship` holds. MountPoints is PASS while zoomed.
## Why: docs/why/ShipScreen.md#zoom-in-place
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

## Measured from the longest part, since a flat 72 clipped siege drivers on a zoomed heavy.
## Why: docs/why/ShipScreen.md#module-overhang
const MOUNT_CELLS := 4
func _bleed() -> float:
	var mag := _view.art_scale() if _view != null else 1.0
	return float((MOUNT_CELLS + 1) * HoldGrid.CELL) * 0.5 * maxf(mag, 1.0)

## Puts the ship's middle on the panel's middle, allowing for the flag, half the view and
## the plume offset.
## Why: docs/why/ShipScreen.md#ship-centring
func _ship_x() -> float:
	if _view == null or _clip == null:
		return 0.0
	# Measured off the window: rebuilding its width from constants gave a second opinion that
	# disagreed.
	var win := maxf(_clip.size.x, _row_width())
	var wide := _view.canvas_width()
	# The plume offset applies only while the ship fits; zoomed, it pushed a heavy 123px off
	# the window.
	# Why: docs/why/ShipScreen.md#ship-centring
	if wide > win:
		return (win - wide) * 0.5
	return (win - wide) * 0.5 - _view.ship_offset_x()

## Rename the ship, in a panel over the screen.

## Same width as the title screen prompts: the width is the edge the eye lines up against.
const RENAME_W := 356

## Not an AcceptDialog: its embedded Window paints Godot's border. Built and freed each
## time.
## Why: docs/why/ShipScreen.md#rename-prompt-build
func _open_rename() -> void:
	if Run.hull == null or _rename != null:
		return
	_rename = rename_prompt(self, func() -> void:
		_rename = null
		_refresh())


## THE PROMPT, over `host`, shared with LOCAL's cutaway (its pencil by the name).
## `closed` is called once it has gone, set or cancelled. Returns the shade.
static func rename_prompt(host: Control, closed: Callable) -> Control:
	# The shade eats input and a click on the dim margin closes, like every other prompt.
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.80)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var close := func() -> void:
		if is_instance_valid(shade):
			shade.queue_free()
		closed.call()
	shade.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close.call())
	host.add_child(shade)

	var mid := CenterContainer.new()
	mid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(mid)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(UITheme.body("NAME YOUR SHIP", UITheme.ICE, UITheme.FS_HEAD))

	var field := UITheme.field(24)
	# The frame name is the placeholder, not prefilled, so SET on an accidental open changes
	# nothing.
	field.placeholder_text = Run.hull.name
	field.text = Run.ship_name
	field.max_length = NAME_MAX
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	field.select_all_on_focus = true
	col.add_child(field)

	col.add_child(UITheme.body(
		"Empty keeps the frame's own name. Names survive a hull swap.",
		UITheme.COLD, UITheme.FS_SMALL))

	var commit := func() -> void:
		# Stripped: a spaces-only name would show a blank masthead line with no explanation.
		Run.ship_name = field.text.strip_edges()
		Sig.ship_changed.emit()
		close.call()
	# ENTER SETS IT. The field is the only thing focused when this opens, so the
	# key you would reach for has to be wired to the button you would click.
	field.text_submitted.connect(func(_t: String) -> void: commit.call())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(Widgets.button("SET", commit))
	# The quiet half of the pair, in the ink the title screen leaves its
	# back-out options in.
	var cancel := Widgets.button("CANCEL", close)
	cancel.add_theme_color_override("font_color", UITheme.LEAVE)
	cancel.add_theme_color_override("font_hover_color", UITheme.LEAVE.lightened(0.3))
	cancel.add_theme_color_override("font_focus_color", UITheme.LEAVE)
	row.add_child(cancel)
	col.add_child(row)

	var card := Widgets.panel_with(col)
	card.custom_minimum_size = Vector2(RENAME_W, 0)
	# The card stops the press, so only the dim margin dismisses.
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	mid.add_child(card)
	field.grab_focus()
	return shade


func _close_rename() -> void:
	if _rename == null:
		return
	_rename.queue_free()
	_rename = null


## Placed by hand because it is top level; resized on both panel and box width changes.
## Why: docs/why/ShipScreen.md#perk-corner
static func fill_perks(box: Control, right: bool, inline: bool = false) -> void:
	Widgets.clear(box)
	# --- WHAT YOU HAVE BECOME, above what the hull came with.
	# Perks (from the frame) and set chips (assembled) share a corner as always-on effects.
	# Shows only what applies now, unlike the removed set-bonus ladder.
	# Why: docs/why/ShipScreen.md#perk-corner
	var live := HBoxContainer.new()
	live.add_theme_constant_override("separation", 3)
	live.size_flags_horizontal = Control.SIZE_SHRINK_END if right else Control.SIZE_SHRINK_BEGIN
	for mid in DB.manufacturers:
		var have := Run.manufacturer_count(mid)
		# One toward a set is enough to show a chip, counting the hull, to match
		# `manufacturer_count`.
		# Why: docs/why/ShipScreen.md#perk-corner
		var parts := 0
		for inst in Run.installed:
			if inst.manufacturer == mid:
				parts += 1
		if have < 1:
			continue
		var mk: ManufacturerData = DB.manufacturers[mid]
		var chip := HudBar.SetChip.new()
		chip.manufacturer = mid
		chip.mark = mk.colour
		chip.field = mk.field
		# ITS OWN HOVER, unlike the perk labels beside it: a chip is one fact and
		# has room to state itself -- `setup` gives it that, panel and all.
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.setup(have, parts)
		live.add_child(chip)
	if live.get_child_count() > 0:
		box.add_child(live)
	var names: Array[String] = []
	for pid in Run.hull.perks():
		var pd: Dictionary = DB.hull_perks.get(pid, {})
		if not pd.is_empty():
			names.append(str(pd.name).to_upper())
	if inline and not names.is_empty():
		var one := UITheme.body(" · ".join(names), UITheme.EMBER, UITheme.FS_SMALL)
		one.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		one.custom_minimum_size.x = 160
		one.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(one)
		names.clear()
	for nm in names:
		var lab := UITheme.body(nm, UITheme.EMBER,
			UITheme.FS_SMALL)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
		# IGNORE, so the hover falls through to the BOX: one tooltip for the whole
		# corner, grouped by origin, rather than four hovers to read four perks.
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(lab)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	# The tooltip text is the trigger; the full text stays so a failed panel build still
	# reads.
	box.tooltip_text = Widgets.tip(Widgets.perk_tip(Run.hull))


## THE RUN'S ROUTINES (science), into `box` (cleared first): one line, "ROUTINES
## · 4 OF 9", the names and what each does on hover (`RoutineBox`). Hidden with
## none bought, so a run that never reaches a Lab shows the panel it always had.
## Kept OUT of `fill_perks`: the perks are the hull's and change at a yard, the
## routines are the flight computer's and do not, and one block for both would
## hide which is which.
static func fill_routines(box: Control) -> void:
	Widgets.clear(box)
	var owned := Run.owned_routines()
	box.visible = not owned.is_empty()
	if owned.is_empty():
		box.tooltip_text = ""
		return
	var line := UITheme.body("ROUTINES · %d OF %d" % [owned.size(), Run.board.size()],
		UITheme.EMBER, UITheme.FS_SMALL)
	# IGNORE, so the hover falls through to the box and its one panel
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.tooltip_text = Widgets.tip(RoutineBox.tip_text())


func _place_perks() -> void:
	if _perkbox == null or _panel == null:
		return
	_perkbox.position = (_panel.global_position
		+ Vector2(_panel.size.x - _perkbox.size.x - PANEL_PAD, PANEL_PAD)).round()

## The window is the whole row at 1x too: the canvas width put an edge on the longest gun.
func _sync_clip() -> void:
	if _clip == null or _view == null:
		return
	# A FLOOR, not a fixed size: the window expands into the rest of the row.
	var box := Vector2(maxf(_row_width(), 1.0), float(HULL_VIEW_H))
	_clip.custom_minimum_size = box
	box.x = maxf(_clip.size.x, box.x)
	box.y = maxf(_clip.size.y, box.y)
	# The box fills the row, so there is nothing left for the pad to do.
	if _padl != null:
		_padl.custom_minimum_size = Vector2.ZERO
	_view.size = Vector2(_view.canvas_width(), _view.canvas_height())
	_clamp_pan()
	_view.position = (Vector2(_ship_x(), (box.y - _view.size.y) * 0.5)
		+ _pan).floor()
	# Mounts must be told: they place through `ShipView.canvas_to_local`, which just changed.
	if _mountpts != null:
		_mountpts.refresh()
		# And again once layout has settled: the call above runs before the
		# container has resized its children, so it places against the OLD rect.
		_mountpts.refresh.call_deferred()

## Clamped in `_sync_clip` so any source of `_pan` is legal by construction, not only
## drags.
## Why: docs/why/ShipScreen.md#pan-clamp
func _clamp_pan() -> void:
	if _clip == null or _view == null:
		return
	# Clamped against the ship's edges, not symmetric slack, so the hull is never dragged out
	# of its window.
	# Why: docs/why/ShipScreen.md#pan-clamp
	var bleed := _bleed()
	var base := _ship_x()
	# A ship that fits has nowhere to go: the wide-hull rule shifted a medium 15px off centre
	# on relayout.
	# Why: docs/why/ShipScreen.md#pan-clamp
	if _view.size.x <= _clip.size.x:
		_pan.x = 0.0
	else:
		var lo := _clip.size.x - _view.size.x - bleed - base
		var hi := bleed - base
		_pan.x = clampf(_pan.x, minf(lo, hi), maxf(lo, hi))
	# Vertically there is nothing overhanging to reach for, so this stays a
	# plain slack: enough to see the top and bottom of a zoomed hull.
	var slack_y := maxf((_view.size.y - _clip.size.y) * 0.5, 0.0) + bleed * 0.25
	_pan.y = clampf(_pan.y, -slack_y, slack_y)

## Pan only while zoomed and not carrying: a lifted part is a live drag and slid the ship
## away.
func _on_clip_input(event: InputEvent) -> void:
	# Not at 1x: a 30px motion there moved the ship permanently, as nothing zeroes `_pan` but
	# zoom off.
	# Why: docs/why/ShipScreen.md#pan-at-1x
	if not _zoomed:
		_panning = false
		if _pan != Vector2.ZERO:
			_pan = Vector2.ZERO
			_sync_clip()
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_panning = mb.pressed and not get_viewport().gui_is_dragging()
		return
	var mm := event as InputEventMouseMotion
	if mm == null or not _panning:
		return
	# Only while the button is down: a release elsewhere left `_panning` stuck and the ship
	# followed.
	if not (mm.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_panning = false
		return
	if get_viewport().gui_is_dragging():
		_panning = false
		return
	_pan += mm.relative
	_clamp_pan()
	_view.position = (Vector2(_ship_x(),
		(_clip.size.y - _view.size.y) * 0.5) + _pan).floor()
	if _mountpts != null:
		_mountpts.refresh()

## Drawing only, no revalidation: a flipped gun keeps its mount, energy and damage.
func _flip_pointed() -> bool:
	if _mountpts == null:
		return false
	return flip_at(_mountpts, _mountpts.get_local_mouse_position())


## F, shared with LOCAL's cutaway: the fitted part at `at` (the mounts' own
## coordinates) mirrored. Whether there was one.
static func flip_at(mounts: MountPoints, at: Vector2) -> bool:
	var m := mounts.part_under(at)
	if m == null:
		return false
	m.flipped = not m.flipped
	# F on a mounted part is the same gesture as R in the hold, so it makes
	# the same sound (Jon asked).
	Audio.play(&"hold_turn", 0.10)
	mounts.refresh()
	return true

func _turn_carried() -> bool:
	return turn_carried(get_viewport())


## R on the thing in the hand, shared with LOCAL's cutaway.
static func turn_carried(vp: Viewport) -> bool:
	var d: Variant = vp.gui_get_drag_data()
	if typeof(d) != TYPE_DICTIONARY or not (d as Dictionary).has("module"):
		return false
	# A HoldItem, not a ModuleData: crates turn too, and `-- materialtest` accepts turned
	# shapes.
	var m: HoldItem = (d as Dictionary).module
	if m == null:
		return false
	m.turned = not m.turned
	# The turn sound for a part in the hand too, not only one in the hold:
	# turning while carrying is the common case and it was silent.
	Audio.play(&"hold_turn", 0.10)
	if ItemIcon.carried != null and is_instance_valid(ItemIcon.carried):
		ItemIcon.carried.fit_footprint()
		ItemIcon.carried.spin()
	return true


## Take out and put back must fail cleanly, leaving the part where it was. `at` is an
## argument so `-- fittest` can reach it; pushed events never move the OS cursor.
## Why: docs/why/ShipScreen.md#turning-in-the-hold
func _turn_in_hold(at: Vector2) -> bool:
	if _storage == null:
		return false
	return turn_in_hold(_storage, at)


## Uses `item_at` not `icon_at`, so a crate turns like a module; a turn that does not fit
## puts it back.
## Why: docs/why/ShipScreen.md#turning-in-the-hold
static func turn_in_hold(grid: HoldGrid, at: Vector2) -> bool:
	var icon := grid.item_at(at)
	if icon == null or icon.held_item() == null:
		return false
	var m := icon.held_item()
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
	Audio.play(&"hold_turn", 0.10)
	grid.refresh()
	var now := grid.item_at(at)
	if now != null:
		now.spin()
	return true


func _refresh() -> void:
	if Run.hull == null:
		return
	# A hull change can change canvas width and offset, so refit the clip box before centring.
	_sync_clip()
	var manufacturer := Run.hull.manufacturer
	var m: ManufacturerData = DB.manufacturers.get(manufacturer)
	var accent := m.colour if m != null else UITheme.CHILL
	_banner.manufacturer = manufacturer
	_banner.mark = accent
	_banner.field = m.field if m != null else UITheme.PANEL
	_banner.queue_redraw()
	# A named ship replaces the frame name outright, reversed on request: both read as the
	# rename not taking.
	# Why: docs/why/ShipScreen.md#ship-naming
	_name.text = Run.display_name().to_upper()
	_manufacturer.text = m.name.to_upper() if m != null else "UNBRANDED SALVAGE"
	_manufacturer.add_theme_color_override("font_color", accent)
	_class.text = "%s CHASSIS · %s TIER" % [
		HullData.weight_name(Run.hull.weight).to_upper(), Run.hull.tier_letter()]
	_attrs.setup(Run.attributes(), accent)
	_refresh_mounts()
	var draw := Run.power_draw()
	var cap := Run.power_cap()
	_reactor.text = "REACTOR — %d of %d cells · %d energy" % [draw, cap, Run.reactor()]
	# Ember only at the ceiling: colour on the way up teaches reading the colour, not the
	# number.
	_reactor.add_theme_color_override("font_color",
		UITheme.EMBER if draw >= cap else UITheme.CHILL)
	_hand.text = "%d cards a turn · %d in the deck" % [Run.hand_size(), Run.deck_size()]

	# Rebuilt every refresh so fitting a third Korvan part lights the 3+ row at once.
	if _perkbox != null:
		fill_perks(_perkbox, true)
		_place_perks.call_deferred()

	# --- the hardpoints are ON THE SHIP now, drawn over the view on the left.
	# Hardpoints are on the ship now; a rack of squares could not say where a mount is.
	if _mountpts != null:
		_mountpts.refresh()

	_storage.refresh()
	# Cells not parts, since shapes decide room. The deck count comes from what is bolted on.
	# An untouched ship after a hull swap honestly reads zero cards.
	# Why: docs/why/ShipScreen.md#hold-and-deck-counts
	_hold.text = "STORAGE — %d of %d cells · DECK %d" % [Run.cargo_used(),
		Run.cargo_slots(), Run.deck_size()]

	# Hidden when empty, not zero-height: a container still spends the separation above an
	# invisible child.
	var docked_items := Run.pad.size()
	_dockhead.visible = docked_items > 0
	_dockbox.visible = docked_items > 0
	if docked_items > 0:
		_dockhead.text = "ON THE PAD — %d thing%s with nowhere to go" % [
			docked_items, "" if docked_items == 1 else "s"]
		_dock.cols = maxi(1, Run.hold_grid().x)
		_dock.refresh()

	_refresh_loadout()

## Grouped by slot to show which mounts are filled; cards at hand scale, the scale they are
## played at.
## Why: docs/why/ShipScreen.md#loadout-panel
func _focus_part(m: ModuleData, slot: MarginContainer = null,
		on: bool = false) -> void:
	if _mountpts != null:
		_mountpts.focus(m)
	if slot == null:
		return
	# One tween per row, killed first; `has_meta` avoids the engine error from `get_meta(key,
	# null)`.
	# Why: docs/why/ShipScreen.md#row-nudge-tweens
	var old: Tween = slot.get_meta(&"nudge") as Tween if slot.has_meta(&"nudge") else null
	if old != null and old.is_valid():
		old.kill()
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(v: float) -> void:
		slot.add_theme_constant_override("margin_left", int(round(v))),
		float(slot.get_theme_constant("margin_left")),
		NUDGE if on else 0.0, 0.12)
	slot.set_meta(&"nudge", tw)

## Malfunction cards come off no module, so the deck panel showed nothing. Put first, drawn
## as cards.
## Why: docs/why/ShipScreen.md#dross-block
func _dross_block() -> void:
	if Run.dross_count() <= 0:
		return
	_fitted.add_child(UITheme.body("MALFUNCTIONS — %d IN YOUR DECK"
		% Run.dross_count(), UITheme.LEAVE, UITheme.FS_SMALL))
	var tally: Dictionary = {}
	for id in Run.dross:
		tally[id] = int(tally.get(id, 0)) + 1
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 4)
	for id in tally:
		var card := DB.malfunction(id)
		if card == null:
			continue
		var cv := CardView.new()
		cv.setup(card, true, 1)
		# The pointer reaches it so `CardView._make_custom_tooltip` can explain a card never read
		# before.
		cv.mouse_filter = Control.MOUSE_FILTER_STOP
		cv.tooltip_text = " "
		mrow.add_child(cv)
		var many: int = tally[id]
		if many > 1:
			var x := UITheme.body("x%d" % many, UITheme.LEAVE, UITheme.FS_SMALL)
			x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			mrow.add_child(x)
	_fitted.add_child(mrow)
	# No caption: where to clear it is the station's job, and the card shows its own rules.
	_fitted.add_child(UITheme.hsep())


func _refresh_loadout() -> void:
	if _fitted == null:
		return
	Widgets.clear(_fitted)

	_dross_block()

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
			# Module first, then its cards, so rows read in decision order and the colour bar scans
			# by manufacturer.
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			# A CARD'S WIDTH exactly, so the rows line up into a column. Left to
			# itself the box grows to its longest line and no two modules agree.
			var ro := Widgets.module_readout(m, READOUT_W)
			# STOP because `module_readout` returns an IGNORE panel, built for tooltips; here it is
			# the target.
			ro.mouse_filter = Control.MOUSE_FILTER_STOP
			var slot := MarginContainer.new()
			slot.add_theme_constant_override("margin_left", 0)
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(ro)
			# Tick on move: Jon asked for the sound the interface makes when something answers a
			# hover.
			ro.mouse_entered.connect(func() -> void:
				Audio.hover()
				_focus_part(m, slot, true))
			ro.mouse_exited.connect(_focus_part.bind(null, slot, false))
			row.add_child(slot)
			for c in m.resolved_cards():
				cards += 1
				var cv := CardView.new()
				# True is not about affordability: `playable` false renders 34% alpha and the panel
				# looked disabled.
				cv.setup(c, true, 1)
				# IGNORE. These are a readout, not a hand: a card that eats the
				# mouse here would swallow the scroll wheel over half the panel.
				cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(cv)
			_fitted.add_child(row)

	if fitted == 0:
		_fitted.add_child(UITheme.body("Nothing installed yet.",
			UITheme.COLD, UITheme.FS_SMALL))

	_fithead.text = "INSTALLED — %d of %d mounts · %d card%s%s" % [
		fitted, mounts, cards, "" if cards == 1 else "s",
		"" if Run.dross_count() == 0
		else " · %d MALFUNCTION%s" % [Run.dross_count(),
			"" if Run.dross_count() == 1 else "S"]]

## Pads reserve to the chassis select's ceiling so figures align. Spacers share slack by
## equal weight.
## Why: docs/why/ShipScreen.md#spacers-and-tally
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

## `index` is carried from the stored `mount`, not derived from `installed` order, or the
## old bug returns.
## Why: docs/why/ShipScreen.md#drop-handlers
func _on_lift(m: ModuleData) -> void:
	if m == null or not Run.installed.has(m):
		return
	_lifted = m
	_lifted_mount = Run.lift_part(m)
	Audio.play(&"hold_lift", 0.08)
	_refresh()


## A drag that never landed puts the part back where it was, like a refused hold move.
func _on_release() -> void:
	var m := _lifted
	_lifted = null
	if m == null or Run.installed.has(m) or Run.cargo.has(m):
		return
	Run.unlift_part(m, _lifted_mount)
	_refresh()


func _on_mount_drop(payload: Dictionary, slot: ModuleData.Slot, index: int) -> void:
	# THE RULE IS RUN'S (`RunState.fit_at_mount`): trade, fit, or refuse. This
	# screen only says which part, which mount, and whether the part is in the hand.
	var m: ModuleData = payload.get("module")
	if m == null:
		return
	var r := Run.fit_at_mount(m, slot, index, _lifted_mount if m == _lifted else -1)
	if r == Run.Refit.REFUSED:
		return
	# (a fit always empties the hand; a trade only when it was the hand's part)
	if r == Run.Refit.FITTED or m == _lifted:
		_lifted = null
	Audio.act(&"module_install")
	_refresh()

## Take out then put back, for every case, so no path can duplicate a module.
## Why: docs/why/ShipScreen.md#drop-handlers
func _on_hold_drop(payload: Dictionary, at: Vector2i) -> void:
	# A HoldItem: typed as `ModuleData` the assignment failed for a crate and the drop
	# silently did nothing.
	var m: HoldItem = payload.get("module")
	if m == null:
		return
	# THE RULE IS RUN'S (`RunState.stow_at`): a refused drop costs nothing, and a
	# part off the ship that will not fit stays in the hand for the release.
	if not Run.stow_at(m, at, m == _lifted):
		_refresh()
		return
	if m == _lifted:
		_lifted = null
	Audio.play(&"hold_stow", 0.08)
	_refresh()


## Drawn, not typed: the UI font has no pencil and an EDIT label reads as part of the
## ship's name.
## Why: docs/why/ShipScreen.md#name-plate
class NameEdit extends Button:
	## Eleven art pixels is the ceiling: FS_HEAD capitals are ten tall and a larger square
	## reads as a panel.
	## Why: docs/why/ShipScreen.md#name-plate
	const ART := 11.0
	## The horizontal pad counts toward the gap to the name, so three here keeps the mark
	## attached.
	## Why: docs/why/ShipScreen.md#name-plate
	const PAD_X := 3.0
	const PAD_Y := 4.0

	## Dropped below COLD so the resting mark waits behind the text and hover lifts read as
	## switching on.
	## Why: docs/why/ShipScreen.md#name-plate
	const REST_DIM := 0.34

	## Silkscreen capitals are 5 of 8 pixels; `get_ascent` counts leading, so centring on it is
	## wrong.
	## Why: docs/why/ShipScreen.md#name-plate
	const CAP_RATIO := 5.0 / 8.0

	## Offset below the box middle: the caps' ink sits 1.5px under it, and the plate rode high
	## otherwise.
	## Why: docs/why/ShipScreen.md#name-plate
	var _drop: float = 0.0

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		flat = true
		custom_minimum_size = Vector2(ART + PAD_X * 2.0, ART + PAD_Y * 2.0)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var f := UITheme.pixel_font()
		var asc := f.get_ascent(UITheme.FS_HEAD)
		var desc := f.get_descent(UITheme.FS_HEAD)
		var cap := float(UITheme.FS_HEAD) * CAP_RATIO
		_drop = roundf((asc - cap * 0.5) - (asc + desc) * 0.5)
		# Through `tip()` like every tooltip, so it wraps at TOOLTIP_WRAP and matches its
		# neighbours.
		tooltip_text = Widgets.tip("Rename your ship.")
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		# Grey until pointed at: it is an action, so rest stays out of the masthead and lights
		# ember on hover.
		var hot := is_hovered()
		var edge := UITheme.ICE if hot else UITheme.COLD.darkened(REST_DIM)
		var mark := UITheme.EMBER if hot else UITheme.COLD.darkened(REST_DIM)
		var o := Vector2((size.x - ART) * 0.5,
			(size.y - ART) * 0.5 + _drop).floor()
		# Four rects, not an unfilled `draw_rect`: its float width can land on half a pixel.
		draw_rect(Rect2(o, Vector2(ART, 1)), edge, true)
		draw_rect(Rect2(o + Vector2(0, ART - 1), Vector2(ART, 1)), edge, true)
		draw_rect(Rect2(o, Vector2(1, ART)), edge, true)
		draw_rect(Rect2(o + Vector2(ART - 1, 0), Vector2(1, ART)), edge, true)
		# Two unequal bars read as a name over its subtitle, not a gauge; the pair sits centred as
		# a block.
		# Why: docs/why/ShipScreen.md#name-plate
		draw_rect(Rect2(o + Vector2(2, 4), Vector2(7, 1)), mark, true)
		draw_rect(Rect2(o + Vector2(2, 6), Vector2(5, 1)), mark, true)
