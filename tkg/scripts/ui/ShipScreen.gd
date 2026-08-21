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
## Every state change goes through _on_dropped. Cells report where a part came
## from and where it landed; nothing else in here touches `installed` or
## `cargo`, so there is one place to read when a swap does the wrong thing.

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
const STORAGE_COLS := 4

var _hardpoints: VBoxContainer
var _storage: GridContainer
var _attrs: AttrBlock
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
	left.add_theme_constant_override("separation", 4)

	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 1)
	_name = UITheme.body("", UITheme.ICE, UITheme.FS_HEAD)
	names.add_child(_name)
	# Who built it, in their own colour, directly under the ship's name — the two
	# halves of what this thing IS. The frame and tier are a separate, greyer
	# fact underneath, and the hull perk is not here at all: the abilities block
	# below already states it as BUILT IN, and saying it twice made the subtitle
	# a duplicate of a row six lines down.
	_maker = UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)
	names.add_child(_maker)
	_class = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	names.add_child(_class)
	left.add_child(names)

	# The banner hangs the full depth of the ship rather than a badge sitting
	# beside a name. It is the same flag the chassis cards fly and it is the one
	# piece of this panel that says whose yard built the thing you are looking
	# at, so it gets the height the subject has — a 26px badge next to two lines
	# of text read as a bullet point.
	var shiprow := HBoxContainer.new()
	shiprow.add_theme_constant_override("separation", 8)
	_banner = ChassisSelect.Banner.new()
	shiprow.add_child(_banner)

	# Doubled and cropped to the hull, the same treatment the chassis select
	# gives it. At 1x in a panel this size the ship was a small object adrift in
	# a lot of nothing, which is the wrong impression for the screen whose
	# subject it is. SHRINK_CENTER inside an expanding wrapper puts it in the
	# middle of the space the banner leaves rather than hard against the flag.
	var view := ShipView.new()
	# 2x. Integer scaling is the whole pixel-art rule, so the ship is either its
	# own size or exactly double and there is nothing in between. 184 rows: the
	# canvas is cropped to 88, doubling needs 176, plus bob headroom.
	view.magnify(2, 184)
	view.bob(2)
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var vwrap := HBoxContainer.new()
	vwrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vwrap.add_child(view)
	shiprow.add_child(vwrap)
	left.add_child(shiprow)

	left.add_child(UITheme.body("ATTRIBUTES", UITheme.COLD, UITheme.FS_SMALL))
	_attrs = AttrBlock.new()
	left.add_child(_attrs)

	_hand = UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)
	left.add_child(_hand)

	# The abilities go here, not on the chassis select's terms. There they
	# answer "what would flying this house give me"; here they answer "how close
	# am I now", and the answer changes every time you drop a part into a mount
	# on the other half of this screen. Under the attributes because it is the
	# same column of facts about the ship — what it is, then what it unlocks.
	#
	# Given real air above it. They are two different KINDS of fact — six gauges
	# you read at a glance, then three conditional rules you read as sentences —
	# and at the column's 4px separation they ran together as one list.
	var abgap := Control.new()
	abgap.custom_minimum_size = Vector2(0, 10)
	abgap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(abgap)
	left.add_child(UITheme.body("MANUFACTURER ABILITIES", UITheme.COLD, UITheme.FS_SMALL))
	_abilities = VBoxContainer.new()
	_abilities.add_theme_constant_override("separation", 1)
	left.add_child(_abilities)

	# The slack goes at the BOTTOM, in one place. Spread through the column — as
	# it was when the ship view expanded — it opened a gap between the ship and
	# its own numbers, which are the two things this half is comparing.
	var lgap := Control.new()
	lgap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lgap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(lgap)

	var lwrap := Widgets.panel_with(left)
	lwrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(lwrap)

	# --- right: the parts, and where they go
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	right.add_child(UITheme.body("HARDPOINTS", UITheme.COLD, UITheme.FS_SMALL))

	_hardpoints = VBoxContainer.new()
	_hardpoints.add_theme_constant_override("separation", 3)
	right.add_child(_hardpoints)

	right.add_child(UITheme.hsep())

	_hold = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	right.add_child(_hold)

	_storage = GridContainer.new()
	_storage.columns = STORAGE_COLS
	_storage.add_theme_constant_override("h_separation", 3)
	_storage.add_theme_constant_override("v_separation", 3)
	right.add_child(_storage)

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

func _refresh() -> void:
	if Run.hull == null:
		return
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

	# --- hardpoints, one row per slot type, occupied first then the empties
	Widgets.clear(_hardpoints)
	for s in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]:
		_hardpoints.add_child(_slot_row(s))

	Widgets.clear(_storage)
	for m in Run.cargo:
		var cell := ModuleCell.new()
		cell.setup(ModuleCell.Kind.STORAGE, m.slot, m)
		cell.dropped.connect(_on_dropped)
		_storage.add_child(cell)
	# Padded out to a full grid. The hold has no cap in the rules, so this is
	# not capacity — it is somewhere to aim. A ragged row of two squares gives
	# you nothing to drop onto and reads as a list that happens to be short;
	# rows of empties read as an inventory with room in it, which is the true
	# thing and the more useful one.
	# Padded to the hold's real capacity, so the empty squares are not decoration
	# — they are how many more parts this hull will take. A heavy shows twelve
	# and a skiff four, which is the compensation the heavy is owed for being
	# unable to dodge or turn.
	var pad := maxi(Run.cargo_slots() - Run.cargo.size(), 0)
	for i in pad:
		var spare := ModuleCell.new()
		spare.setup(ModuleCell.Kind.STORAGE, ModuleData.Slot.WEAPON, null)
		spare.dropped.connect(_on_dropped)
		_storage.add_child(spare)
	_hold.text = "STORAGE — %d of %d" % [Run.cargo.size(), Run.cargo_slots()]

func _slot_row(slot: ModuleData.Slot) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var label := UITheme.body(ModuleData.slot_name(slot).to_upper(),
		UITheme.COLD, UITheme.FS_SMALL)
	label.custom_minimum_size = Vector2(52, 0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	# One cell per PHYSICAL mount, asking what is bolted to that one. Packing the
	# fitted parts in from the left instead made the rack a queue: taking the
	# middle gun off slid the last one into its place, both here and on the hull
	# art, so a loadout you had arranged rearranged itself.
	for i in Run.slots_for(slot):
		var cell := ModuleCell.new()
		cell.setup(ModuleCell.Kind.HARDPOINT, slot, Run.module_at(slot, i), i)
		cell.dropped.connect(_on_dropped)
		row.add_child(cell)
	return row

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
func _hold_would_take(parts: Array[ModuleData]) -> bool:
	var placed: Array[ModuleData] = []
	var ok := true
	for p in parts:
		if Run.place_in_hold(p):
			placed.append(p)
		else:
			ok = false
			break
	for p in placed:
		Run.take_from_hold(p)
	return ok

func _on_dropped(payload: Dictionary, onto: ModuleCell) -> void:
	var m: ModuleData = payload.get("module")
	if m == null:
		return

	# Dropping something on the mount it already occupies is a no-op, not a
	# swap with itself.
	if onto.held == m:
		return

	# Two fitted parts trading mounts EXCHANGE places rather than sending one to
	# the hold. Now that a mount is a position you chose, dragging one gun onto
	# another is you arranging the ship, and arranging it must not cost you the
	# part you dragged onto — nor need hold space you may not have.
	if onto.kind == ModuleCell.Kind.HARDPOINT and onto.held != null \
			and Run.installed.has(m) and Run.installed.has(onto.held):
		var there := onto.held.mount
		onto.held.mount = m.mount
		m.mount = there
		Sig.ship_changed.emit()
		_refresh()
		return

	# Anything that ENDS with a part in the hold has to be checked first: taking
	# a module off, and swapping one out for another. Refused before the move
	# rather than after, because half a swap leaves a module belonging to
	# nowhere — and the count is measured against `m` already being counted
	# where it is, which is why the installed case allows one more than free.
	var to_hold := 0
	if onto.kind != ModuleCell.Kind.HARDPOINT and Run.installed.has(m):
		to_hold += 1
	if onto.kind == ModuleCell.Kind.HARDPOINT and onto.held != null:
		to_hold += 1
	# Room is asked about the SPECIFIC parts, not about a count. A hold with
	# three free cells takes three sights, or one compact unit, or a long gun
	# only if the free cells happen to lie in a row — `cargo.size() + n` cannot
	# express any of that.
	#
	# Checked BEFORE anything moves, and checked against the hold as it will be:
	# `m` is lifted first so a part swapping into the mount it already sits
	# beside is not refused by its own cells.
	var was_at := m.hold_at
	var lifted := Run.cargo.has(m)
	if lifted:
		Run.take_from_hold(m)
	var homeless: Array[ModuleData] = []
	if onto.kind != ModuleCell.Kind.HARDPOINT and Run.installed.has(m):
		homeless.append(m)
	if onto.kind == ModuleCell.Kind.HARDPOINT and onto.held != null:
		homeless.append(onto.held)
	if not _hold_would_take(homeless):
		if lifted:
			Run.place_in_hold(m, was_at)
		Run.log_line("No room in the hold.", &"them")
		return

	Run.installed.erase(m)

	match onto.kind:
		ModuleCell.Kind.HARDPOINT:
			# The resident goes to the hold. It cannot stay: the mount is the
			# thing being taken, and there is nowhere else for it to be.
			if onto.held != null:
				Run.installed.erase(onto.held)
				onto.held.mount = -1
				Run.place_in_hold(onto.held)
			m.mount = onto.index
			Run.installed.append(m)
		_:
			m.mount = -1
			# Onto the cell the cursor is over when there is one, so the hold is
			# arranged rather than merely filled; otherwise first fit.
			if not Run.place_in_hold(m, onto.cell if onto.cell != -Vector2i.ONE else -Vector2i.ONE):
				Run.place_in_hold(m)

	Sig.ship_changed.emit()
	Run.log_line("Refitted %s." % m.name, &"sys")
	_refresh()
